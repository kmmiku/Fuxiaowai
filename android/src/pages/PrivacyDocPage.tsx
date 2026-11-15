import { clearPersonalData } from '../core/cleanup';
import { useEffect, useState } from 'react';

import { useApp } from '../core/appState';
import { back, param, replace, useRoute } from '../core/router';
import { toast } from '../ui/toast';

/**
 * 隐私与合规说明 —— 1:1 对照 entry/src/main/ets/pages/PrivacyDocPage.ets
 * 一套壳子按 kind 渲染五份文档：collect / share / permission / export / revoke
 */

interface Section {
  head: string;
  lines: string[];
  tag?: string;
}

interface RowItem {
  k: string;
  v: string;
}

interface Doc {
  title: string;
  intro: string;
  rows: RowItem[];
  sections: Section[];
}

const DOCS: Record<string, Doc> = {
  collect: {
    title: '个人信息收集清单',
    intro:
      '课表、成绩和登录资料主要保存在本机。主动分享会向福小外服务上传课表快照；提交反馈会上传所填内容、联系方式和选择的图片。',
    rows: [
      { k: '学号', v: '登录正方教务系统、区分课表归属' },
      {
        k: '教务密码',
        v: '用于直接登录学校；勾选记住密码时由 Android Keystore 保护后保存在本机，不发送到福小外服务器'
      },
      {
        k: '姓名 / 专业 / 班级 / 年级',
        v: '展示在“我的”页面；由课表接口的 xsxx 字段顺带返回'
      },
      { k: '课程表', v: '核心功能；同步时整表写入本机存储' },
      { k: '成绩', v: '成绩查询功能；按学期从教务拉取' },
      { k: '反馈文字与图片', v: '提交后上传到福小外反馈服务；网络失败先保留在本机等待补发' },
      { k: '上课时间设置', v: '自定义节次起止，决定课表时间轴' }
    ],
    sections: []
  },
  share: {
    title: '第三方信息共享清单',
    intro: '学校登录由手机直接连接学校；主动分享和反馈使用福小外自建HTTPS服务。学校部分接口仍使用HTTP，不能视为全程加密传输。',
    rows: [],
    sections: [
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
        head: '福小外分享与反馈服务（fuxiaowai.xyz）',
        tag: '主动上传',
        lines: [
          '主动分享时上传课程、节次、学期和周次，生成可读取快照的分享口令',
          '反馈提交时上传填写的文字、联系方式、所选图片、应用版本和设备信息；服务会记录请求 IP',
          '通过 HTTPS 连接；本机退出不删除云端分享或反馈，云端删除需另行联系处理'
        ]
      },
      {
        head: 'Android 系统服务',
        tag: '系统能力',
        lines: [
          '剪贴板：分享课表时写入，由你手动粘贴',
          '文件选择器：反馈时选择图片，只读取你选中的那一张',
          '提醒服务：生成上课提醒，数据留在系统内',
          '以上均在本机完成，不上传'
        ]
      },
      {
        head: '未接入的第三方',
        tag: '说明',
        lines: [
          '本 App 未集成广告、统计、推送、崩溃上报等任何 SDK',
          '没有账号体系，不需要手机号、邮箱注册'
        ]
      }
    ]
  },
  permission: {
    title: '权限中心',
    intro:
      '福小外申请的权限都可以在系统“设置 → 应用 → 福小外 → 权限”里随时关闭，关闭后对应功能不可用，其余功能不受影响。',
    rows: [
      { k: 'POST_NOTIFICATIONS', v: '发布上课提醒；关闭后“上课提醒”页无法排程' },
      {
        k: 'READ_CALENDAR',
        v: '读取你在系统日历里已创建的课表日程，用于避免重复导入'
      },
      {
        k: 'WRITE_CALENDAR',
        v: '把课表导出为系统日历日程、创建上课提醒；只在点“导出到日程”时申请'
      },
      { k: '相册 / 文件（按需）', v: '反馈时添加图片；只在点“添加图片”时弹出选择器' },
      { k: '网络（默认）', v: '访问学校教务系统；无网络时显示本地缓存课表' }
    ],
    sections: []
  },
  export: {
    title: '个人信息导出',
    intro:
      '把本机保存的课表、成绩与个人资料导出为 JSON 文本并复制到剪贴板，你可以粘贴到备忘录或发给自己保存。导出过程完全在本机完成。',
    rows: [],
    sections: []
  },
  revoke: {
    title: '隐私协议撤回',
    intro:
      '撤回后将清理本机个人信息、会话及本应用登记的提醒和日程，并回到未登录状态；系统权限不足时需重试。此操作不代表已删除云端分享或反馈，云端删除需另行联系处理。',
    rows: [],
    sections: [
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
    ]
  }
};

/** 写剪贴板；WebView 下 clipboard API 不可用时退回 execCommand */
async function copyText(text: string): Promise<boolean> {
  try {
    await navigator.clipboard.writeText(text);
    return true;
  } catch {
    try {
      const ta = document.createElement('textarea');
      ta.value = text;
      ta.style.position = 'fixed';
      ta.style.top = '0';
      ta.style.opacity = '0';
      document.body.appendChild(ta);
      ta.select();
      const ok = document.execCommand('copy');
      document.body.removeChild(ta);
      return ok;
    } catch {
      return false;
    }
  }
}

export default function PrivacyDocPage() {
  const app = useApp();
  const { path, params } = useRoute();
  const fromPath = path.startsWith('/privacy/') ? path.slice('/privacy/'.length) : '';
  const kind = param<string>(params, 'kind', fromPath.length > 0 ? fromPath : 'collect');
  const doc = DOCS[kind] ?? DOCS.revoke;

  const [busy, setBusy] = useState(false);
  const [showConfirm, setShowConfirm] = useState(false);
  const [exported, setExported] = useState('');

  useEffect(() => {
    document.title = `${doc.title} · 福小外`;
  }, [doc.title]);

  const p = app.profile;

  async function doExport() {
    if (busy) return;
    setBusy(true);
    try {
      const payload = {
        app: '福小外',
        exportedAt: new Date().toISOString(),
        profile: p,
        courses: app.courses,
        feedback: app.feedback
      };
      const text = JSON.stringify(payload, null, 2);
      setExported(text);
      const ok = await copyText(text);
      toast(ok ? `已导出 ${app.courses.length} 门课与个人资料到剪贴板` : '导出失败，请稍后再试');
    } catch {
      toast('导出失败，请稍后再试');
    } finally {
      setBusy(false);
    }
  }

  async function doRevoke() {
    if (busy) return;
    setBusy(true);
    try {
      await clearPersonalData(true, app.reload);
      setShowConfirm(false);
      toast('已撤回并清除本机数据');
      window.setTimeout(() => replace('/home'), 700);
    } catch {
      toast('清除失败，请重试');
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="pm-page">
      <div className="pm-head pm-head--doc">
        <button className="pm-back" onClick={() => back()} aria-label="返回">
          ‹
        </button>
        <div className="pm-title pm-title--flex">{doc.title}</div>
      </div>

      <div className="pm-body pm-body--doc">
        <div className="pm-doc-intro">{doc.intro}</div>

        {doc.rows.length > 0 ? (
          <div className="pm-card">
            {doc.rows.map((r, i) => (
              <div key={r.k}>
                <div className="pm-doc-kv-item">
                  <div className="pm-doc-kv-k">{r.k}</div>
                  <div className="pm-doc-kv-v">{r.v}</div>
                </div>
                {i < doc.rows.length - 1 ? <div className="pm-divider pm-divider--16" /> : null}
              </div>
            ))}
          </div>
        ) : null}

        {doc.sections.length > 0 ? (
          <div className="pm-card">
            {doc.sections.map((s, i) => (
              <div key={s.head}>
                <div className="pm-doc-section">
                  <div className="pm-doc-sec-head">
                    <div className="pm-doc-sec-title">{s.head}</div>
                    {s.tag ? <div className="pm-doc-tag">{s.tag}</div> : null}
                  </div>
                  {s.lines.map((ln) => (
                    <div className="pm-doc-line" key={ln}>
                      <div className="pm-doc-dot">·</div>
                      <div className="pm-doc-line-text">{ln}</div>
                    </div>
                  ))}
                </div>
                {i < doc.sections.length - 1 ? <div className="pm-divider pm-divider--16" /> : null}
              </div>
            ))}
          </div>
        ) : null}

        {kind === 'export' ? (
          <div className="pm-doc-action">
            <button className="pm-doc-btn pm-doc-btn--primary" disabled={busy} onClick={doExport}>
              {busy ? '正在打包…' : '导出我的数据到剪贴板'}
            </button>
            <div className="pm-doc-action-note">
              {`当前本机：${p.name.length > 0 ? p.name : '未登录'} · ${
                p.studentId.length > 0 ? p.studentId : '无学号'
              }`}
            </div>
          </div>
        ) : null}

        {kind === 'export' && exported.length > 0 ? (
          <pre className="pm-doc-json">{exported}</pre>
        ) : null}

        {kind === 'revoke' ? (
          <div className="pm-doc-action">
            <button
              className="pm-doc-btn pm-doc-btn--soft"
              onClick={() => setShowConfirm(true)}
            >
              撤回同意并清除本机数据
            </button>
            <div className="pm-doc-action-note">撤回后需重新登录才能同步课表</div>
          </div>
        ) : null}

        <div className="pm-doc-foot">福小外 · 登录资料主要保存在本机，主动分享和反馈会上传指定内容</div>
      </div>

      {showConfirm ? (
        <>
          <div className="pm-mask" onClick={() => setShowConfirm(false)} />
          <div className="pm-sheet pm-sheet--revoke">
            <div className="pm-grabber" />
            <div className="pm-doc-confirm">
              <div className="pm-doc-confirm-title">确认撤回？</div>
              <div className="pm-doc-confirm-text">
                登录凭据、课表、成绩、个人资料和反馈草稿都会被删除，且无法恢复。
              </div>
              <div className="pm-doc-confirm-actions">
                <button
                  className="pm-doc-confirm-btn pm-doc-confirm-btn--ghost"
                  onClick={() => setShowConfirm(false)}
                >
                  取消
                </button>
                <button
                  className="pm-doc-confirm-btn pm-doc-confirm-btn--danger"
                  disabled={busy}
                  onClick={doRevoke}
                >
                  {busy ? '处理中…' : '确认撤回'}
                </button>
              </div>
            </div>
          </div>
        </>
      ) : null}
    </div>
  );
}