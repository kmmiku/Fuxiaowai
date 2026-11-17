/** 字符级换行，与Text的BREAK_ALL配合，数字不作为不可拆分词。 */
export function wrappedLineCount(widths: number[], available: number): number {
  if (widths.length === 0) { return 0; }
  let lines: number = 1;
  let used: number = 0;
  const limit: number = Math.max(1, available - 1);
  widths.forEach((width: number) => {
    if (width < 0) { lines++; used = 0; return; }
    if (used > 0 && used + width > limit) { lines++; used = 0; }
    used += width;
  });
  return lines;
}
export function courseNameLines(height: number, roomLines: number): number {
  const available: number = Math.max(16, height - 16);
  const reserve: number = roomLines > 0 ? Math.min(Math.max(32, roomLines * 16), Math.max(16, available - 16)) : 0;
  return Math.max(1, Math.floor((available - reserve) / 16));
}

/** 常见教室编号固定为楼号/末三位房间号两行。 */
export function fixedRoomCode(code: string): string {
  const matched: RegExpMatchArray | null = code.trim().match(/^((?:教|实|[A-Za-z])?\s*\d+?)[-－—]?(\d{3})$/);
  return matched ? matched[1].replace(/\s/g, '') + '\n' + matched[2] : code;
}
