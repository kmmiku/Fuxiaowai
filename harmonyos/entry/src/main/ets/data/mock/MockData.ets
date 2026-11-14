import { Course, colorIndexOf } from '../../domain/model/Course';

/**
 * 演示数据：来自企业微信课表截图（第11周）
 * 仅用于 M1 阶段跑通 UI，后续由 FuwaiAdapter 解析教务 JSON 覆盖
 */
function c(
  name: string, teacher: string, room: string,
  weekday: number, sp: number, ep: number, weeks: number[]
): Course {
  return {
    id: `${name}-${weekday}-${sp}`,
    name: name,
    teacher: teacher,
    room: room,
    campus: '长乐校区',
    weekday: weekday,
    startPeriod: sp,
    endPeriod: ep,
    weeks: weeks,
    colorIndex: colorIndexOf(name)
  };
}

const W1_16: number[] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16];

export const MOCK_COURSES: Course[] = [
  c('高级数据库技术', '梁艳', '教4203', 1, 1, 2, W1_16),
  c('形势与政策5', '杨艺璇', '教150', 1, 5, 5, W1_16),
  c('Hadoop开发技术', '张国煜', '实360 3数据3分析实验室', 2, 1, 4, W1_16),
  c('高性能系统架构', '卢公明', '教540 4计算机基础实验室（一）', 3, 1, 2, W1_16),
  c('机器学习', '张紫铃', '实330 3', 3, 3, 4, W1_16),
  c('虚拟化技术', '李玉颖', '教520 2', 3, 3, 4, W1_16),
  c('数据采集与处理', '刘海涛', '教430 1', 4, 1, 2, W1_16),
  c('Hadoop开发技术', '张国煜', '实510 3大数据与信息技术实验室', 4, 3, 4, W1_16),
  c('机器学习', '张紫铃', '实550 4计算机基础实验室（二）', 4, 5, 7, W1_16),
  c('HarmonyOS应用开发实践（产业）', '余能辉', '实130 1计算机网络与信息安全实验室', 5, 1, 4, W1_16),
  c('虚拟化技术', '李玉颖', '教550 2虚拟化技术实验室', 7, 3, 4, W1_16)
];

/** 第11周的日期（11月10日周一 ~ 11月16日周日） */
export const MOCK_DATES: string[] = ['10', '11', '12', '13', '14', '15', '16'];