import { useEffect, useState } from 'react';

import { navigate } from '../core/router';

/** 常见问题：登录、课表、提醒 */

interface QA {
  q: string;
  a: string;
}

const LIST: QA[] = [
  {
    q: '登录时提示「学号或密码不正确」怎么办？',
    a: '教务系统和教学综合平台是两套密码，可能不一样。在登录页下方切换圆形单选框，分别试一次：走教务入口用教务密码，走教学综合平台入口用统一身份认证密码。'
  },
  {
    q: '导入课表后一直是空的？',
    a: '多半是学期还没开始、课表没发布，或者当前学期选错了。到「我的 → 课表设置」确认学期，再重新导入一次。'
  },
  {
    q: '在校外连不上教务？',
    a: '教务只对校内网开放。校外请先连学校 VPN，或用「我的 → 网络检测」确认教务是否可达。'
  },
  {
    q: '为什么同一时间有两门课？',
    a: '课表会把时间重叠的课横向分成两列并排显示，不会互相遮挡。点开任意一块可以看周次、地点、教师，也可以只从本周移除。'
  },
  {
    q: '提醒是弹窗还是系统通知？',
    a: '「上课提醒」里可以选：软件内提醒（App 开着时在顶部弹条）或系统通知（App 没开也能收到）。导出到系统日历的日程，提醒由系统日历负责。'
  },
  {
    q: '分享口令发给别人，对方导入不了？',
    a: '口令需要先上传到福小外后台才能被他人使用。生成口令时如果显示「离线口令」，说明当时没连上服务器，换个网络重新生成即可。'
  },
  {
    q: '卸载重装会丢数据吗？',
    a: '会。课表、账号、头像、反馈都存在本机，卸载即清除。重要课表可以先「分享课表」生成口令留档。'
  }
];

export default function FaqPage() {
  const [open, setOpen] = useState<number>(-1);

  useEffect(() => {
    document.title = '常见问题 · 福小外';
  }, []);

  return (
    <div className="pm-page">
      <div className="pm-head">
        <button className="pm-back" onClick={() => navigate('/profile')} aria-label="返回">
          ←
        </button>
        <div className="pm-title">常见问题</div>
      </div>

      <div className="pm-body">
        <div className="pm-card">
          {LIST.map((item, i) => (
            <div key={item.q}>
              <button className="pm-faq" data-open={open === i} onClick={() => setOpen(open === i ? -1 : i)}>
                <span className="pm-faq-q">{item.q}</span>
                <span className="pm-faq-mark">{open === i ? '−' : '+'}</span>
              </button>
              {open === i ? <div className="pm-faq-a">{item.a}</div> : null}
              {i === LIST.length - 1 ? null : <div className="pm-divider" />}
            </div>
          ))}
        </div>

        <div className="pm-note">没找到答案？到「我的 → 反馈问题」写给我们，也可以附截图。</div>
      </div>
    </div>
  );
}