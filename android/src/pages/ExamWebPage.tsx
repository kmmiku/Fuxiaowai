import { useEffect, useState } from 'react';
import { Capacitor, registerPlugin } from '@capacitor/core';

import { navigate } from '../core/router';
import { EXAM_PAGE_URL, cookieHeader, hasSession } from '../core/zhengfang';
import { toast } from '../ui/toast';
import '../styles/px-grade.css';

/** 原生侧教务页面（ExamWebPlugin / ExamWebActivity） */
interface FxwWebPlugin {
  open(options: { url: string; cookie: string; title: string }): Promise<{ opened: boolean }>;
}

const Web = registerPlugin<FxwWebPlugin>('FxwWeb');

/**
 * 教务原始页面（成绩查询 / 考试安排）。
 *
 * 教务的页面要求「一等公民」上下文才认 Cookie：iframe 嵌在 https://localhost 里属于第三方，
 * WebView 不发注入的 JSESSIONID，页面会掉回统一身份认证。这里改用应用内原生 WebView，
 * 打开前把当前会话的 Cookie 写进 CookieManager。
 */
export default function ExamWebPage() {
  const [signedIn, setSignedIn] = useState(true);
  const [opening, setOpening] = useState(false);
  const [nonce, setNonce] = useState(0);

  useEffect(() => {
    document.title = '成绩查询 · 福小外';
  }, []);

  useEffect(() => {
    setSignedIn(hasSession());
  }, [nonce]);

  async function openWeb(): Promise<void> {
    if (opening) return;
    if (!hasSession()) {
      toast('请先登录教务系统');
      return;
    }
    if (!Capacitor.isNativePlatform()) {
      window.open(EXAM_PAGE_URL, '_blank', 'noopener');
      return;
    }
    setOpening(true);
    try {
      await Web.open({ url: EXAM_PAGE_URL, cookie: cookieHeader(), title: '成绩查询' });
    } catch (e) {
      toast(`打不开教务页面：${e instanceof Error ? e.message : String(e)}`);
    } finally {
      setOpening(false);
    }
  }

  useEffect(() => {
    void openWeb();
    // 进页就打开一次；用户回来后可以点「重新打开」
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  return (
    <div className="pxw-page">
      <div className="pxw-head">
        <button className="pxw-back" onClick={() => navigate('/exam')} aria-label="返回">
          ‹
        </button>
        <div className="pxw-title">{signedIn ? '成绩查询' : '登录教务系统'}</div>
        <button className="pxw-icon" onClick={() => setNonce((n) => n + 1)} aria-label="刷新">
          ↻
        </button>
        <button className="pxw-open" onClick={() => window.open(EXAM_PAGE_URL, '_blank', 'noopener')}>
          用浏览器
        </button>
      </div>

      <div className="pxw-body">
        {signedIn ? (
          <div className="pxw-err">
            <div className="pxw-err-title">{opening ? '正在打开教务页面…' : '教务页面已在应用内打开'}</div>
            <div className="pxw-err-tip">
              成绩和考试安排由教务系统直接渲染。页面里选学期、点查询即可；返回这里可以重新打开。
            </div>
            <button className="pxw-retry" onClick={() => void openWeb()}>
              重新打开
            </button>
          </div>
        ) : (
          <div className="pxw-err">
            <div className="pxw-err-title">请先登录教务系统</div>
            <div className="pxw-err-tip">
              内置页面用的是你导入课表时的会话，登录一次就能直接看到成绩和考试安排。
            </div>
            <button className="pxw-retry" onClick={() => navigate('/login')}>
              去登录
            </button>
          </div>
        )}
      </div>
    </div>
  );
}