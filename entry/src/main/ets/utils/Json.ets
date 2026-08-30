/**
 * JSON 安全访问工具。
 *
 * ArkTS 禁止 any/implicit any，直接对 JSON.parse 结果做属性访问无法通过类型检查。
 * 统一通过 Record<string, Object> + 显式类型收窄读取字段，缺失字段回退默认值。
 */

export type JsonMap = Record<string, Object>;

export class Json {
  /** 读取字符串字段，缺失或类型不符返回 fallback */
  static str(o: JsonMap, key: string, fallback: string = ''): string {
    const v: Object | undefined = o[key];
    return typeof v === 'string' ? v as string : fallback;
  }

  /** 读取数值字段，缺失或类型不符返回 fallback */
  static num(o: JsonMap, key: string, fallback: number = 0): number {
    const v: Object | undefined = o[key];
    return typeof v === 'number' ? v as number : fallback;
  }

  /** 读取布尔字段，缺失或类型不符返回 fallback */
  static bool(o: JsonMap, key: string, fallback: boolean = false): boolean {
    const v: Object | undefined = o[key];
    return typeof v === 'boolean' ? v as boolean : fallback;
  }

  /** 读取嵌套对象字段，缺失返回 null */
  static obj(o: JsonMap, key: string): JsonMap | null {
    const v: Object | undefined = o[key];
    return (v !== null && v !== undefined && typeof v === 'object') ? v as JsonMap : null;
  }

  /** 读取数组字段，缺失返回空数组 */
  static arr(o: JsonMap, key: string): Object[] {
    const v: Object | undefined = o[key];
    return Array.isArray(v) ? v as Object[] : [];
  }

  /** 安全解析 JSON 文本，失败返回 null */
  static parse(text: string): JsonMap | null {
    try {
      const parsed: Object | null = JSON.parse(text);
      return (parsed !== null && typeof parsed === 'object') ? parsed as JsonMap : null;
    } catch (e) {
      return null;
    }
  }
}
