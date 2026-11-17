/** 实测星期列宽决定vp范围；跨屏保存比例而非绝对值。 */
export function widthMin(column: number): number {
  return Math.ceil(Math.max(1, column) * 0.8 * 10) / 10;
}
export function widthMax(column: number): number {
  return Math.floor(Math.max(1, column) * 10) / 10;
}
export function effectiveWidth(column: number, ratio: number, legacy: number): number {
  const value: number = ratio > 0 ? column * ratio : (legacy > 0 ? legacy : column);
  return Math.min(widthMax(column), Math.max(widthMin(column), value));
}
