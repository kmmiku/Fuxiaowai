import router from '@ohos.router';
import promptAction from '@ohos.promptAction';
import pasteboard from '@ohos.pasteboard';
import common from '@ohos.app.ability.common';
import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { Profile, ProfileStore } from '../data/local/ProfileStore';
import { CredentialStore } from '../data/local/CredentialStore';
import { FeedbackStore } from '../data/local/FeedbackStore';
import { Locator } from '../app/di/ServiceLocator';
import { Course } from '../domain/model/Course';

interface ExportTable { id: string; name: string; courses: Course[]; }

/** 一段正文 */
interface Section {
  head: string;
  lines: string[];
  /** 小标题（可空） */
  tag?: string;
}

interface RowItem {
  k: string;
  v: string;
}

/**
 * 隐私与合规说明页：一套壳子，按 kind 渲染五份文档
 * collect / share / export / permission / revoke
 */
@Entry
@Component
struct PrivacyDocPage {
  @StorageLink('dark') dark: boolean = false;
  @State kind: string = 'collect';
  @State title: string = '';
  @State intro: string = '';
  @State sections: Section[] = [];
  @State rows: RowItem[] = [];
  @State profile: Profile = {
    name: '', studentId: '', clazz: '', major: '', grade: '', updatedAt: 0
  };
  @State busy: boolean = false;
  @State showConfirm: boolean = false;

  aboutToAppear(): void {
    const p = router.getParams() as Record<string, string>;
    this.kind = (p && p.kind) ? p.kind : 'collect';
    this.buildContent();
    this.loadProfile();
  }

  private async loadProfile(): Promise<void> {
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    this.profile = await ProfileStore.load(ctx);
  }

  private toast(msg: string): void {
    try {
      promptAction.showToast({ message: msg, duration: 2000 });
    } catch (e) {
      console.info(`Fuxiaowai: privacy toast ${msg}`);
    }
  }

  private buildContent(): void {
    if (this.kind === 'collect') {
      this.title = '个人信息收集清单';
      this.intro = '课表、成绩与个人资料主要保存在本机。主动分享课表或提交反馈时，所选内容会发送到福小外服务；成功登录后上报学号用于去重人数统计，服务端仅保存 HMAC 摘要、递增用户 ID 与首次注册时间。';
      this.rows = [
        { k: '学号', v: '登录教务、区分课表归属；登录成功后在开发者服务器内存计算 HMAC 去重，原学号不落盘；过渡 HTTP 传输存在被截获风险' },
        { k: '教务密码', v: '登录学校时按学校协议加密；记住的密码经 HUKS 加密保存在本机' },
        { k: '姓名 / 专业 / 班级 / 年级', v: '展示在“我的”页面；由课表接口的 xsxx 字段顺带返回' },
        { k: '课程表', v: '核心功能；同步时整表写入本机数据库' },
        { k: '成绩', v: '成绩查询功能；按学期从教务拉取' },
        { k: '反馈文字与图片', v: '提交后发送到福小外服务；失败留在本机等待重试，包含填写的联系方式与版本信息' },
        { k: '考试安排缓存', v: '考试安排按账号保存在本机；退出或撤回隐私同意时清除' },
        { k: '上课时间设置', v: '自定义节次起止，决定课表时间轴' }
      ];
      return;
    }

    if (this.kind === 'share') {
      this.title = '第三方信息共享清单';
      this.intro = '手机直接连接学校认证与教务服务；主动分享、反馈或成功登录统计时连接福小外服务，扫码时连接企业微信。';
      this.sections = [
        { head: '学校官网与中国教育考试网', tag: '主动访问', lines: ['点击工作台服务后通过内置网页连接学校官网或考试院，适用对应站点政策', '四六级报名及查询由考试院自行认证；不向官网或考试院注入教务 Cookie', '网页会话保存在系统 WebView 中；退出账号时清理 Cookie'] },
        {
          head: '正方教务系统（jw.fzfu.edu.cn）',
          tag: '数据来源',
          lines: [
            '共享内容：学号、RSA 加密后的密码、会话 Cookie、学期参数',
            '用途：登录、拉取课表与成绩',
            '方式：由手机直接连接学校服务器，不经过任何中间服务器',
            '对方的隐私政策由福州外语外贸学院教务处提供'
          ]
        },
        {
          head: '华为系统服务',
          tag: '系统能力',
          lines: [
            '剪贴板：分享课表时写入，由你手动粘贴',
            '文件选择器：反馈时选择图片，只读取你选中的那一张',
            '提醒服务：生成上课提醒，数据留在系统内',
            '以上均在本机完成，不上传'
          ]
        },
        {
          head: '福小外与企业微信服务',
          tag: '说明',
          lines: [
            '福小外服务接收主动分享的课表快照、反馈内容、联系方式、图片、版本与请求 IP',
            '登录成功后学号用于服务器内存 HMAC 去重，持久保存摘要、递增用户 ID 与首次注册时间；统计标识保留至服务终止，过渡 HTTP 存在截获风险',
            '分享口令有效期 30 天；云端删除可通过反馈申请，本机退出不等于删除云端数据',
            '企业微信扫码用于取得学校登录凭证；学校 HTTP 链路不具备 HTTPS 传输保护'
          ]
        }
      ];
      return;
    }

    if (this.kind === 'permission') {
      this.title = '权限中心';
      this.intro = '福小外申请的权限都可以在系统“设置 → 应用 → 福小外 → 权限”里随时关闭，关闭后对应功能不可用，其余功能不受影响。';
      this.rows = [
        { k: 'PUBLISH_AGENT_REMINDER', v: '发布上课提醒；关闭后“上课提醒”页无法排程' },
        { k: 'READ_CALENDAR', v: '识别本应用已导出的课表日程，避免重复导入和清理旧日程' },
        { k: 'WRITE_CALENDAR', v: '把课表导出为系统日历日程、创建上课提醒；只在点“导出到日程”时申请' },
        { k: '相册 / 文件（按需）', v: '反馈时添加图片；只在点“添加图片”时弹出选择器' },
        { k: '网络（默认）', v: '访问学校教务系统；无网络时显示本地缓存课表' }
      ];
      return;
    }

    if (this.kind === 'export') {
      this.title = '个人信息导出';
      this.intro = '把本机保存的课表、成绩与个人资料导出为 JSON 文本并复制到剪贴板，你可以粘贴到备忘录或发给自己保存。导出过程完全在本机完成。';
      return;
    }

    this.title = '隐私协议撤回';
    this.intro = '撤回同意后，福小外会删除本机保存的全部个人信息（登录凭据、个人资料、课表、成绩、反馈草稿），并回到未登录状态。此操作不可撤销。';
    this.sections = [
      {
        head: '撤回后会发生什么',
        tag: '影响',
        lines: [
          '登录凭据被清除，需要重新输入学号和密码才能同步课表',
          '本机课表、成绩、个人资料一并删除',
          '未提交的反馈草稿会被丢弃',
          'App 本身不会被卸载，可以重新登录继续使用'
        ]
      }
    ];
  }

  /** 导出：课表 + 成绩 + 资料 → JSON → 剪贴板 */
  private async doExport(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await Locator.init(ctx);
      const tables = await Locator.repo().tables();
      const courses = await Locator.repo().listAll('t1');
      const allTables: ExportTable[] = [];
      for (const table of tables) {
        const item: ExportTable = { id: table.id, name: table.name,
          courses: await Locator.repo().listAll(table.id) };
        allTables.push(item);
      }
      const grades = await Locator.loadGradeCache(this.profile.studentId);
      const feedback = await FeedbackStore.list(ctx);
      const payload: Record<string, Object> = {
        'app': '福小外',
        'exportedAt': new Date().toISOString(),
        'profile': this.profile,
        'courses': courses,
        'timetables': allTables,
        'grades': grades === null ? [] : grades.items,
        'feedback': feedback
      };
      const text = JSON.stringify(payload, null, 2);
      const data = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await pasteboard.getSystemPasteboard().setData(data);
      this.toast(`已导出 ${courses.length} 门课与个人资料到剪贴板`);
    } catch (e) {
      this.toast('导出失败，请稍后再试');
      console.info(`Fuxiaowai: export failed ${JSON.stringify(e)}`);
    } finally {
      this.busy = false;
    }
  }

  /** 撤回：清空全部本地数据 */
  private async doRevoke(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    const ctx: common.UIAbilityContext = getContext(this) as common.UIAbilityContext;
    try {
      await Locator.init(ctx);
      await Locator.clearPersonalData();
      this.showConfirm = false;
      this.toast('已撤回并清除本机数据');
      setTimeout(() => {
        router.clear();
        router.replaceUrl({ url: 'pages/Index' });
      }, 700);
    } catch (e) {
      this.toast('清除失败，请重试');
      console.info(`Fuxiaowai: revoke failed ${JSON.stringify(e)}`);
    } finally {
      this.busy = false;
    }
  }

  @Builder
  headerBar() {
    Row() {
      Text('‹')
        .fontSize(26)
        .fontColor(TC(this.dark).text)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .onClick(() => router.back())
      Text(this.title)
        .fontSize(Font.title)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .layoutWeight(1)
        .margin({ left: 4 })
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .width('100%')
    .padding({ left: 6, right: 12, top: 6, bottom: 6 })
  }

  @Builder
  keyValueCard() {
    Column() {
      ForEach(this.rows, (r: RowItem, i: number) => {
        Column() {
          Text(r.k)
            .fontSize(Font.body)
            .fontColor(TC(this.dark).text)
          Text(r.v)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
            .margin({ top: 4 })
            .lineHeight(19)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        if (i < this.rows.length - 1) {
          Divider().color(TC(this.dark).line).margin({ left: 16 })
        }
      }, (r: RowItem) => r.k)
    }
    .width('100%')
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
  }

  @Builder
  sectionCard() {
    Column() {
      ForEach(this.sections, (s: Section, i: number) => {
        Column() {
          Row() {
            Text(s.head)
              .fontSize(Font.body)
              .fontWeight(FontWeight.Medium)
              .fontColor(TC(this.dark).text)
              .layoutWeight(1)
            if (s.tag) {
              Text(s.tag)
                .fontSize(10)
                .fontColor(Palette.primary)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .borderRadius(4)
                .backgroundColor(this.dark ? '#232A44' : '#EEF1FB')
            }
          }
          .width('100%')

          ForEach(s.lines, (ln: string) => {
            Row() {
              Text('·')
                .fontSize(Font.small)
                .fontColor(TC(this.dark).textHint)
              Text(ln)
                .fontSize(Font.small)
                .fontColor(TC(this.dark).textSub)
                .lineHeight(20)
                .layoutWeight(1)
                .margin({ left: 6 })
            }
            .width('100%')
            .alignItems(VerticalAlign.Top)
            .margin({ top: 8 })
          }, (ln: string) => ln)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })

        if (i < this.sections.length - 1) {
          Divider().color(TC(this.dark).line).margin({ left: 16 })
        }
      }, (s: Section) => s.head)
    }
    .width('100%')
    .backgroundColor(TC(this.dark).card)
    .borderRadius(Metric.cardRadius)
  }

  @Builder
  actionArea() {
    if (this.kind === 'export') {
      Column() {
        Button(this.busy ? '正在打包…' : '导出我的数据到剪贴板')
          .width('100%')
          .height(44)
          .fontSize(Font.body)
          .fontColor(Color.White)
          .backgroundColor(Palette.primary)
          .borderRadius(12)
          .enabled(!this.busy)
          .onClick(() => {
            this.doExport();
          })
        Text(`当前本机：${this.profile.name.length > 0 ? this.profile.name : '未登录'} · ${this.profile.studentId.length > 0 ? this.profile.studentId : '无学号'}`)
          .fontSize(Font.tiny)
          .fontColor(TC(this.dark).textHint)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 10 })
      }
      .width('100%')
      .margin({ top: 16 })
    }

    if (this.kind === 'revoke') {
      Column() {
        Button('撤回同意并清除本机数据')
          .width('100%')
          .height(44)
          .fontSize(Font.body)
          .fontColor('#B3261E')
          .backgroundColor(this.dark ? '#33222A' : '#FDECEA')
          .borderRadius(12)
          .onClick(() => {
            this.showConfirm = true;
          })
        Text('撤回后需重新登录才能同步课表')
          .fontSize(Font.tiny)
          .fontColor(TC(this.dark).textHint)
          .width('100%')
          .textAlign(TextAlign.Center)
          .margin({ top: 10 })
      }
      .width('100%')
      .margin({ top: 16 })
    }
  }

  build() {
    Column() {
      this.headerBar()

      Scroll() {
        Column() {
          Text(this.intro)
            .fontSize(Font.small)
            .fontColor(TC(this.dark).textSub)
            .lineHeight(20)
            .width('100%')
            .margin({ bottom: 12 })

          if (this.rows.length > 0) {
            this.keyValueCard()
          }
          if (this.sections.length > 0) {
            this.sectionCard()
          }
          this.actionArea()

          Text('福小外 · 开发者服务器处理分享、反馈及登录去重统计')
            .fontSize(10)
            .fontColor(TC(this.dark).textHint)
            .width('100%')
            .textAlign(TextAlign.Center)
            .margin({ top: 18, bottom: 24 })
        }
        .width('100%')
        .padding({ left: 14, right: 14 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
    .bindSheet($$this.showConfirm, this.confirmSheet(), {
      height: 250,
      dragBar: true,
      showClose: false,
      backgroundColor: TC(this.dark).card
    })
  }

  @Builder
  confirmSheet() {
    Column() {
      Text('确认撤回？')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(TC(this.dark).text)
        .margin({ top: 18 })
      Text('登录凭据、课表、成绩、个人资料和反馈草稿都会被删除，且无法恢复。')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textSub)
        .lineHeight(20)
        .width('100%')
        .textAlign(TextAlign.Center)
        .margin({ left: 24, right: 24, top: 10 })
      Blank()
      Row({ space: 10 }) {
        Button('取消')
          .layoutWeight(1)
          .height(42)
          .fontSize(Font.body)
          .fontColor(TC(this.dark).text)
          .backgroundColor(TC(this.dark).chip)
          .onClick(() => {
            this.showConfirm = false;
          })
        Button(this.busy ? '处理中…' : '确认撤回')
          .layoutWeight(1)
          .height(42)
          .fontSize(Font.body)
          .fontColor(Color.White)
          .backgroundColor('#B3261E')
          .enabled(!this.busy)
          .onClick(() => {
            this.doRevoke();
          })
      }
      .width('100%')
      .padding({ left: 20, right: 20, bottom: 22 })
    }
    .width('100%')
    .height('100%')
  }
}

