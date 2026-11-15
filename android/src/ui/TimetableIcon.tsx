/** 课表操作图标：按用户参考图使用圆角线条，颜色继承按钮。 */
export default function TimetableIcon({ name, size = 22 }: {
  name: 'add' | 'import' | 'share' | 'send' | 'calendar' | 'key';
  size?: number;
}) {
  const paths = {
    add: <path d="M12 3v18M3 12h18" />,
    import: <><path d="M9 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V9" /><path d="M20 3c-6 1-9 5-9 12m-4-4 4 4 4-4" /></>,
    share: <><path d="M9 3H5a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-4M14 3h7v7M10 14 21 3" /></>,
    send: <><path d="m3 10 18-7-7 18-3-8-8-3Z M11 13 21 3" /></>,
    calendar: <><rect x="3" y="5" width="18" height="16" rx="3" /><path d="M7 3v4M17 3v4M3 10h18M8 14h8M8 17h5" /></>,
    key: <><circle cx="7.5" cy="7.5" r="4.5" /><path d="m11 11 10 10m-6-6 2-2m1 5 2-2" /><circle cx="6.5" cy="6.5" r=".5" /></>
  };
  return <svg width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true" focusable="false">{paths[name]}</svg>;
}
