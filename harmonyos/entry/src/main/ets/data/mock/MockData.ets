/** 仅用于旧演示记录清理；不再包含课程、教师或教室明文。 */
export function legacyDemoIdHash(value: string): number {
  let h: number = 2166136261;
  for (let i: number = 0; i < value.length; i++) { h = Math.imul(h ^ value.charCodeAt(i), 16777619) >>> 0; }
  return h;
}
export const LEGACY_DEMO_ID_HASHES: number[] = [2748695206, 4223876476, 3899105851, 474799321, 2403506689, 1317189981, 2845237789, 3719394331, 2332873526, 759972937, 4207932433];
