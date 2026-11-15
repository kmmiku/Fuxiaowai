import { useEffect } from 'react';

import { back } from '../core/router';

/**
 * 关于与反馈 —— 1:1 对照 entry/src/main/ets/pages/AboutPage.ets
 * 应用名 + 副标题、六行版本信息、反馈邮箱、页脚免责声明
 */

const ROWS: string[][] = [
  ['版本', 'v0.1.1（开发版）'],
  ['服务院校', '福州外语外贸学院'],
  ['数据来源', '正方教务系统 jwglxt'],
  ['课表范围', '2026—2027 学年 第 1 学期'],
  ['网络', '仅在校验账号时访问教务系统'],
  ['收集信息', '主动分享和反馈按需上传']
];

export default function AboutPage() {
  useEffect(() => {
    document.title = '关于与反馈 · 福小外';
  }, []);

  return (
    <div className="pm-page">
      <div className="pm-head pm-head--bar">
        <button className="pm-back" onClick={() => back()} aria-label="返回">
          ‹
        </button>
        <div className="pm-title">关于与反馈</div>
        <div className="pm-grow" />
      </div>

      <div className="pm-body pm-body--flush">
        <div className="pm-about-head">
          <div className="pm-about-name">福小外</div>
          <div className="pm-about-tag">看得清的课表，记得住的一周</div>
        </div>

        <div className="pm-about-rows">
          {ROWS.map((r, i) => (
            <div key={r[0]}>
              <div className="pm-about-row">
                <div className="pm-about-key">{r[0]}</div>
                <div className="pm-about-val">{r[1]}</div>
              </div>
              {i < ROWS.length - 1 ? (
                <div className="pm-divider pm-divider--16 pm-divider--half" />
              ) : null}
            </div>
          ))}
        </div>

        <div className="pm-about-feedback">
          <div className="pm-about-feedback-title">反馈</div>
          <div className="pm-about-feedback-text">
            遇到课表不对、导入失败，或想加功能，写邮件说明「学号 + 现象 + 截图」，会在两个工作日内回复。
          </div>
          <div className="pm-about-mail">lilixiang2762@gmail.com</div>
        </div>

        <div className="pm-about-foot">
          本应用与学校官方无关，课表数据来自你自己登录后的教务系统。
        </div>
      </div>
    </div>
  );
}