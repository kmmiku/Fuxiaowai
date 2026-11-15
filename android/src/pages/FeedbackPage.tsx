import { deliverFeedback } from '../core/feedbackDelivery';
import { useEffect, useRef, useState } from 'react';
import type { ChangeEvent } from 'react';

import { useApp } from '../core/appState';
import { FeedbackError } from '../core/feedback';
import { back } from '../core/router';
import { toast } from '../ui/toast';

/**
 * 反馈问题 —— 1:1 对照 entry/src/main/ets/pages/FeedbackPage.ets
 * 多行文本（500 字计数）+ 最多 3 张图 + 联系方式 + 提交
 * 提交后上传到HTTPS反馈服务，失败先留本机。
 */

const MAX_IMAGES = 3;
/** 上传用的截图：最长边 900、JPEG 0.78，单张约 60–150 KB，3 张不超 1 MB */
const MAX_SIDE = 900;
const JPEG_QUALITY = 0.78;

function readImage(file: File): Promise<string> {
  if(file.size>15*1024*1024)return Promise.reject(new Error('图片过大，请选择较小图片'));
  return new Promise((resolve, reject) => {
    const reader = new FileReader();
    reader.onerror = () => reject(new Error('读取图片失败'));
    reader.onload = () => {
      const img = new Image();
      img.onerror = () => reject(new Error('图片格式不支持'));
      img.onload = () => {
        const scale = Math.min(1, MAX_SIDE / Math.max(img.width, img.height));
        const w = Math.round(img.width * scale);
        const h = Math.round(img.height * scale);
        const canvas = document.createElement('canvas');
        canvas.width = w;
        canvas.height = h;
        const ctx = canvas.getContext('2d');
        if (!ctx) {
          reject(new Error('无法处理图片'));
          return;
        }
        ctx.drawImage(img, 0, 0, w, h);
        resolve(canvas.toDataURL('image/jpeg', JPEG_QUALITY));
      };
      img.src = String(reader.result);
    };
    reader.readAsDataURL(file);
  });
}

export default function FeedbackPage() {
  const app = useApp();
  const fileRef = useRef<HTMLInputElement | null>(null);
  const [text, setText] = useState('');
  const [contact, setContact] = useState('');
  const [images, setImages] = useState<string[]>([]);
  const [busy, setBusy] = useState(false);
  /** 提交结果弹窗：成功 / 失败都弹一次，让用户明确知道发生了什么 */
  const [result, setResult] = useState<{ ok: boolean; title: string; body: string } | null>(null);
  const retried = useRef(false);

  useEffect(() => {
    document.title = '反馈问题 · 福小外';
  }, []);

  // 进入页面时补发之前没传上去的反馈，一条成功再发下一条，失败就停
  useEffect(() => {
    if (retried.current) return;
    retried.current = true;
    const list = app.feedback.filter((f) => !f.sent);
    if (list.length === 0) return;
    void (async () => {
      for (const f of list) {
        try {
          const sent = await deliverFeedback(f.id);
          if (!sent) continue;
          app.markFeedbackSent(f.id);
        } catch {
          break;
        }
      }
    })();
  }, [app]);

  const pending = app.feedback.filter((f) => !f.sent).length;

  function openPicker() {
    if (busy) return;
    const remain = MAX_IMAGES - images.length;
    if (remain <= 0) {
      toast(`最多添加 ${MAX_IMAGES} 张图片`);
      return;
    }
    const el = fileRef.current;
    if (!el) {
      toast('当前设备没有可用的图库或文件选择器');
      return;
    }
    try {
      el.click();
    } catch {
      toast('当前设备没有可用的图库或文件选择器');
    }
  }

  async function onPick(e: ChangeEvent<HTMLInputElement>) {
    // 先把 FileList 拷成数组：紧接着清空 input.value 会把同一个 FileList 一起清掉，
    // 之前拿到的引用会变空 —— 这就是「选了图不显示预览」的根因。
    const picked = e.target.files ? Array.from(e.target.files) : [];
    e.target.value = '';
    if (picked.length === 0) return;
    const remain = MAX_IMAGES - images.length;
    const files = picked.slice(0, Math.max(0, remain));
    const added: string[] = [];
    for (const f of files) {
      try {
        added.push(await readImage(f));
      } catch {
        toast('这张图读取失败，已跳过');
      }
    }
    if (added.length > 0) {
      setImages((prev) => prev.concat(added).slice(0, MAX_IMAGES));
    }
  }

  function removeImage(i: number) {
    setImages((prev) => prev.filter((_, k) => k !== i));
  }

  async function submit() {
    if (busy) return;
    const body = text.trim();
    if (body.length === 0) {
      toast('先说点什么吧');
      return;
    }
    const contactText = contact.trim();
    if (contactText.length === 0) {
      toast('留个联系方式吧，方便我们回你');
      return;
    }
    setBusy(true);
    const id = `fb_${crypto.randomUUID()}`;
    const imgs = images.slice();
    try {
      app.addFeedback({
        id,
        text: body,
        contact: contactText,
        images: imgs,
        createdAt: Date.now(),
        sent: false,
      });
      setText('');
      setContact('');
      setImages([]);

      try {
        const sent = await deliverFeedback(id);
        if (!sent) throw new Error('反馈仍在等待发送，请稍后重试');
        app.markFeedbackSent(id);
        setResult({ ok: true, title: '反馈已提交', body: '谢谢你的反馈，我们会在后续版本里处理。' });
      } catch (err) {
        const limited = err instanceof FeedbackError && err.status === 429;
        if (limited) {
          app.reload();
          setResult({
            ok: false,
            title: '提交太频繁',
            body: '服务器暂时限流，反馈仍保存在本机等待发送；到重试时间后再次进入此页会补发。',
          });
        } else {
          setResult({
            ok: false,
            title: '提交失败',
            body: err instanceof FeedbackError && err.status>=400 && err.status<500 ? `${err.message}；内容仍在本机，尚未发送。` : '当前网络连不上服务器，反馈已存在本机，下次进入反馈页会自动补发。',
          });
        }
      }
    } catch {
      setResult({ ok: false, title: '保存失败', body: '本机存储写入失败，请稍后再试。' });
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="pm-page">
      <div className="pm-head pm-head--feedback">
        <button className="pm-back" onClick={() => back()} aria-label="返回">
          ‹
        </button>
        <div className="pm-title">反馈问题</div>
        <div className="pm-grow" />
        {pending > 0 ? <div className="pm-fb-pending">{`${pending} 条待提交`}</div> : null}
      </div>

      <div className="pm-body pm-body--feedback">
        <div className="pm-fb-text-card">
          <textarea
            className="pm-fb-textarea"
            value={text}
            placeholder="请输入您遇到的问题或建议.."
            maxLength={500}
            onChange={(e) => setText(e.target.value)}
          />
          <div className="pm-fb-count">{`${text.length}/500`}</div>
        </div>

        <div className="pm-fb-media-card">
          <div className="pm-fb-media-head">
            <div className="pm-fb-media-title">图片</div>
            <div className="pm-fb-media-num">{`${images.length}/${MAX_IMAGES}`}</div>
          </div>

          <div className="pm-fb-shots">
            {images.map((uri, i) => (
              <div className="pm-fb-shot" key={`${i}-${uri.slice(0, 24)}`}>
                <img src={uri} alt="" />
                <button
                  className="pm-fb-shot-del"
                  onClick={() => removeImage(i)}
                  aria-label="删除图片"
                >
                  ×
                </button>
              </div>
            ))}

            {images.length < MAX_IMAGES ? (
              <button className="pm-fb-shot-add" onClick={openPicker} aria-label="添加图片">
                <span className="pm-fb-shot-plus">+</span>
                <span className="pm-fb-shot-label">图片</span>
              </button>
            ) : null}
          </div>
        </div>

        <div className="pm-fb-contact-card">
          <div className="pm-fb-contact-row">
            <div className="pm-fb-contact-label">
              联系方式
              <span className="pm-fb-req">*</span>
            </div>
            <input
              className="pm-fb-contact-input"
              value={contact}
              placeholder="必填，手机号 / 微信 / 邮箱"
              onChange={(e) => setContact(e.target.value)}
            />
          </div>
        </div>

        <button className="pm-fb-submit" data-press={busy} disabled={busy} onClick={submit}>
          {busy ? '提交中…' : '提交反馈'}
        </button>

        <div className="pm-fb-foot">
          提交后会直接发送到服务器；网络不通时先存本机，下次进来自动补发
        </div>

        {result ? (
          <div className="pm-mask" onClick={() => setResult(null)}>
            <div className="pm-dialog" onClick={(e) => e.stopPropagation()}>
              <div className={`pm-dialog-icon${result.ok ? ' ok' : ' bad'}`}>{result.ok ? '✓' : '!'}</div>
              <div className="pm-dialog-title">{result.title}</div>
              <div className="pm-dialog-body">{result.body}</div>
              <button className="pm-dialog-btn" onClick={() => setResult(null)}>
                知道了
              </button>
            </div>
          </div>
        ) : null}

        <input
          ref={fileRef}
          type="file"
          accept="image/*"
          multiple
          hidden
          onChange={onPick}
        />
      </div>
    </div>
  );
}