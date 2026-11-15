/**
 * 极简线条图标（纯 SVG，stroke 用 currentColor）
 * 用于「我的」页每行左侧，替代原来的汉字图标（资 / 反 / 表 …）
 */

export type IconName =
  | 'mail' | 'moon' | 'download' | 'clock' | 'sliders' | 'phone'
  | 'user'
  | 'help'
  | 'calendar'
  | 'bell'
  | 'shirt'
  | 'lock'
  | 'info'
  | 'trash'
  | 'wifi'
  | 'grid'
  | 'book'
  | 'award';

interface Props {
  name: IconName;
  /** 图标画布边长，默认 20 */
  size?: number;
}

const S = {
  fill: 'none',
  stroke: 'currentColor',
  strokeWidth: 1.6,
  strokeLinecap: 'round' as const,
  strokeLinejoin: 'round' as const
};

export default function LineIcon({ name, size = 20 }: Props) {
  const common = {
    width: size,
    height: size,
    viewBox: '0 0 24 24',
    'aria-hidden': true,
    focusable: false
  };

  switch (name) {
    case 'mail':
      return <svg {...common}><rect x="3" y="5" width="18" height="14" rx="2" {...S} /><path d="m3 6 9 7 9-7" {...S} /></svg>;
    case 'moon':
      return <svg {...common}><path d="M20.5 14A8.6 8.6 0 0 1 10 3.5 8.6 8.6 0 1 0 20.5 14Z" {...S} /></svg>;
    case 'download':
      return <svg {...common}><path d="M12 3v12m-5-5 5 5 5-5M4 13v7h16v-7" {...S} /></svg>;
    case 'clock':
      return <svg {...common}><circle cx="12" cy="12" r="8.5" {...S} /><path d="M12 6v6l-4 2" {...S} /></svg>;
    case 'sliders':
      return <svg {...common}><path d="M3 6h18M3 12h18M3 18h18" {...S} /><circle cx="8" cy="6" r="2" {...S} fill="var(--chip)" /><circle cx="16" cy="12" r="2" {...S} fill="var(--chip)" /><circle cx="9" cy="18" r="2" {...S} fill="var(--chip)" /></svg>;
    case 'phone':
      return <svg {...common}><rect x="6" y="3" width="12" height="18" rx="2.5" {...S} /><path d="M10 6h4M11 18h2" {...S} /></svg>;
    case 'user':
      return (
        <svg {...common}>
          <circle cx="12" cy="8" r="3.6" {...S} />
          <path d="M4.8 19.6c0-3.6 3.2-5.8 7.2-5.8s7.2 2.2 7.2 5.8" {...S} />
        </svg>
      );
    case 'help':
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="8.4" {...S} />
          <path d="M9.8 9.4a2.3 2.3 0 1 1 3.1 2.2c-.7.3-1 .9-1 1.6v.4" {...S} />
          <circle cx="12" cy="16.8" r=".9" fill="currentColor" stroke="none" />
        </svg>
      );
    case 'calendar':
      return (
        <svg {...common}>
          <rect x="3.6" y="5.4" width="16.8" height="15" rx="2.6" {...S} />
          <path d="M3.6 9.6h16.8M8.2 3.4v3.6M15.8 3.4v3.6" {...S} />
          <path d="M7.6 13h1.6M11.2 13h1.6M14.8 13h1.6M7.6 16.6h1.6M11.2 16.6h1.6" {...S} />
        </svg>
      );
    case 'bell':
      return (
        <svg {...common}>
          <path d="M12 3.8a5.4 5.4 0 0 1 5.4 5.4v3l1.5 2.6H5.1l1.5-2.6v-3A5.4 5.4 0 0 1 12 3.8z" {...S} />
          <path d="M9.6 17.6a2.4 2.4 0 0 0 4.8 0" {...S} />
        </svg>
      );
    case 'shirt':
      return (
        <svg {...common}>
          <path d="M8.6 4.2 4.4 6.6l1.9 3.6 1.7-.9v9.9h8v-9.9l1.7.9 1.9-3.6-4.2-2.4a3.2 3.2 0 0 1-6.8 0z" {...S} />
        </svg>
      );
    case 'lock':
      return (
        <svg {...common}>
          <rect x="4.8" y="10.4" width="14.4" height="9.4" rx="2.4" {...S} />
          <path d="M8.4 10.4V7.9a3.6 3.6 0 0 1 7.2 0v2.5" {...S} />
          <circle cx="12" cy="15" r="1.1" fill="currentColor" stroke="none" />
        </svg>
      );
    case 'info':
      return (
        <svg {...common}>
          <circle cx="12" cy="12" r="8.4" {...S} />
          <path d="M12 10.8v5.4" {...S} />
          <circle cx="12" cy="8.2" r=".9" fill="currentColor" stroke="none" />
        </svg>
      );
    case 'trash':
      return (
        <svg {...common}>
          <path d="M4.8 7.2h14.4M9.4 7.2V5.4h5.2v1.8" {...S} />
          <path d="M6.6 7.2l.9 11.2a1.8 1.8 0 0 0 1.8 1.6h5.4a1.8 1.8 0 0 0 1.8-1.6l.9-11.2" {...S} />
          <path d="M10.4 10.8v5.6M13.6 10.8v5.6" {...S} />
        </svg>
      );
    case 'wifi':
      return (
        <svg {...common}>
          <path d="M2.8 9.2a13.4 13.4 0 0 1 18.4 0" {...S} />
          <path d="M6.2 12.6a8.6 8.6 0 0 1 11.6 0" {...S} />
          <path d="M9.6 16a4 4 0 0 1 4.8 0" {...S} />
          <circle cx="12" cy="19" r=".9" fill="currentColor" stroke="none" />
        </svg>
      );
    case 'book':
      return (
        <svg {...common}>
          <path d="M4.6 5.6v13.2L12 17.2l7.4 1.6V5.6a13 13 0 0 0-7.4 0 13 13 0 0 0-7.4 0Z" {...S} />
          <path d="M12 5.6v11.6" {...S} />
          <path d="M7.6 8.6v3.8M16.4 8.6v3.8" {...S} />
        </svg>
      );
    case 'award':
      return (
        <svg {...common}>
          <circle cx="12" cy="9.4" r="5.6" {...S} />
          <path d="M9.1 13.6 8.1 20.6 12 18.8l3.9 1.8-1-7" {...S} />
        </svg>
      );
    case 'grid':
    default:
      return (
        <svg {...common}>
          <rect x="4" y="4" width="6.4" height="6.4" rx="1.6" {...S} />
          <rect x="13.6" y="4" width="6.4" height="6.4" rx="1.6" {...S} />
          <rect x="4" y="13.6" width="6.4" height="6.4" rx="1.6" {...S} />
          <rect x="13.6" y="13.6" width="6.4" height="6.4" rx="1.6" {...S} />
        </svg>
      );
  }
}
