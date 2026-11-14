import { Font, Metric, Palette, TC } from '../common/design/Tokens';
import { AppSettings, DEFAULT_SETTINGS, SettingsStore } from '../data/local/SettingsStore';
import common from '@ohos.app.ability.common';
import router from '@ohos.router';
import promptAction from '@ohos.promptAction';

/** 外观设置：深色模式 / 主题 */
@Entry
@Component
struct AppearancePage {
  @StorageLink('dark') dark: boolean = false;
  @State s: AppSettings = DEFAULT_SETTINGS;
  private ctx: common.UIAbilityContext | null = null;

  aboutToAppear(): void {
    this.ctx = getContext(this) as common.UIAbilityContext;
    SettingsStore.load(this.ctx).then((v: AppSettings) => {
      this.s = v;
    });
  }

  private persist(): void {
    if (this.ctx) {
      SettingsStore.save(this.ctx, this.s);
    }
  }

  /** 主题标识 → 展示名（目前只有默认） */
  private themeName(): string {
    return this.s.theme === 'default' ? '默认' : this.s.theme;
  }

  build() {
    Column() {
      Row() {
        Text('‹')
          .fontSize(26)
          .fontColor(TC(this.dark).text)
          .width(40)
          .onClick(() => router.back())
        Text('外观设置')
          .fontSize(Font.title)
          .fontWeight(FontWeight.Bold)
          .fontColor(TC(this.dark).text)
        Blank()
      }
      .width('100%')
      .height(60)
      .padding({ left: 8, right: Metric.pagePadding })

      Column() {
        Row() {
          Column() {
            Text('深色模式')
              .fontSize(15)
              .fontColor(TC(this.dark).text)
            Text('夜间看课表不刺眼')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.s.dark })
            .selectedColor(Palette.primary)
            .onChange((v: boolean) => {
              this.s.dark = v;
              AppStorage.setOrCreate('dark', v);
              this.persist();
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })

        Divider().color(TC(this.dark).line).strokeWidth(0.5).margin({ left: 16 })

        Row() {
          Column() {
            Text('主题')
              .fontSize(15)
              .fontColor(TC(this.dark).text)
            Text('课程表配色与卡片风格')
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Row() {
            Text(this.themeName())
              .fontSize(Font.small)
              .fontColor(TC(this.dark).textHint)
            Text('›')
              .fontSize(18)
              .fontColor(TC(this.dark).textHint)
              .margin({ left: 4 })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .onClick(() => {
          promptAction.showToast({ message: '主题功能即将上线', duration: 1600 });
        })
      }
      .backgroundColor(TC(this.dark).card)
      .borderRadius(16)
      .margin({ left: Metric.pagePadding, right: Metric.pagePadding })

      Text('设置即时生效，回到课表即可看到。')
        .fontSize(Font.small)
        .fontColor(TC(this.dark).textHint)
        .width('100%')
        .padding({ left: 20, top: 10 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor(TC(this.dark).bg)
  }
}