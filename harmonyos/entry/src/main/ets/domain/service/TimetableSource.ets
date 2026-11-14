import { Course } from '../model/Course';

/** 学生基本信息（登录后由数据源带回） */
export interface StudentInfo {
  name: string;
  studentId: string;
  clazz: string;
  major: string;
}

export interface FetchOutcome {
  courses: Course[];
  student: StudentInfo;
  semesterLabel: string;
  dropped: number;
  /**
   * 非空 = 这次没拿到课表：统一身份认证要求人机验证，这里是验证码图片（JPEG 字节）。
   * 此时 courses 为空数组，调用方不要落库，弹窗让用户填完再调 resumeCaptcha。
   */
  captcha: ArrayBuffer;
  /** 需要人机验证时的提示文案；正常路径为空串 */
  message: string;
}

/** 一张待扫的登录二维码（PNG 字节） */
export interface QrTicket {
  ok: boolean;
  message: string;
  key: string;
  image: ArrayBuffer;
}

/** 扫码状态：wait 继续等，scanned 已扫待确认，done 可以收尾，其余是终止态 */
export interface QrProgress {
  state: string;
  code: string;
  message: string;
}

/**
 * 课表数据源抽象（domain 层）。
 * 单校目前只有正方一种实现，但保留接口：以后接别的教务/手动导入都不用改用例。
 */
export interface TimetableSource {
  fetch(user: string, pwd: string): Promise<FetchOutcome>;
  /** 人机验证：用用户输入的验证码继续刚才那次登录（实现要自己留着会话） */
  resumeCaptcha(code: string): Promise<FetchOutcome>;
  /** 换一张验证码图；拿不到时返回空 buffer */
  refreshCaptcha(): Promise<ArrayBuffer>;
  /** 企业微信扫码登录：取二维码 */
  qrStart(): Promise<QrTicket>;
  /** 企业微信扫码登录：轮询一次状态 */
  qrPoll(): Promise<QrProgress>;
  /** 企业微信扫码登录：扫码确认后换取登录态并直接取课表 */
  qrLogin(code: string): Promise<FetchOutcome>;
}