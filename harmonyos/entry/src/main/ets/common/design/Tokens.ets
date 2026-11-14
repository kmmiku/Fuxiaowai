/**
 * 设计令牌：颜色 / 字号 / 间距 / 圆角
 * 所有 UI 只引用这里，禁止硬编码色值（便于换肤与深色模式）
 */
export class Palette {
  static readonly bg: string = '#F6F7FB';
  static readonly card: string = '#FFFFFF';
  static readonly text: string = '#1A1A1A';
  static readonly textSub: string = '#6B7280';
  static readonly textHint: string = '#A0A6B1';
  static readonly line: string = '#EEF1F6';
  static readonly primary: string = '#3D5AFE';
  static readonly todayBg: string = '#F0F3FF';
  static readonly gridLine: string = '#F0F2F6';
  static readonly todayMark: string = '#1A1A1A';
  static readonly danger: string = '#E5484D';
  static readonly primaryDeep: string = '#2A3EB1';
  static readonly chip: string = '#F1F3F9';
}

/** 当前主题下的一组底色/文字色；深色模式只换这一层，组件引用 TC(dark) */
export interface ThemeColors {
  bg: string;
  card: string;
  text: string;
  textSub: string;
  textHint: string;
  line: string;
  chip: string;
  gridLine: string;
}

const LIGHT: ThemeColors = {
  bg: Palette.bg,
  card: Palette.card,
  text: Palette.text,
  textSub: Palette.textSub,
  textHint: Palette.textHint,
  line: Palette.line,
  chip: Palette.chip,
  gridLine: Palette.gridLine
};

const DARK: ThemeColors = {
  bg: '#101114',
  card: '#1B1D22',
  text: '#F2F3F7',
  textSub: '#A9AEBD',
  textHint: '#767C8C',
  line: '#2A2D35',
  chip: '#23262D',
  gridLine: '#282B33'
};

export function TC(dark: boolean): ThemeColors {
  return dark ? DARK : LIGHT;
}

/** 课程色板： [浅底, 主色] */
export const COURSE_COLORS: string[][] = [
  ['#EDEBFD', '#7C6CF0'],
  ['#FDF0E3', '#E8892B'],
  ['#E6F6EE', '#2FA36B'],
  ['#E5F4F8', '#2B9BB5'],
  ['#F3E8FA', '#9B59C9'],
  ['#FCE9EE', '#E46A8B'],
  ['#F2F6DF', '#8AA61F'],
  ['#E8F0FD', '#3D7EDB']
];

export class Metric {
  static readonly pagePadding: number = 12;
  static readonly cardRadius: number = 20;
  static readonly blockRadius: number = 8;
  static readonly cellHeight: number = 52;   // 每节课行高
  static readonly timeColWidth: number = 38; // 左侧时间轴宽度
  static readonly gap: number = 12;
}

export class Font {
  static readonly title: number = 24;
  static readonly section: number = 15;
  static readonly body: number = 13;
  static readonly small: number = 11;
  static readonly tiny: number = 9;
}