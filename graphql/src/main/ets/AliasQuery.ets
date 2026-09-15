/**
 * alias 批量查询构造：单请求多 alias 是 GraphQL 减少往返的标准手法。
 *
 * 所有字符串实参必须经 escapeGraphQLString 后内插（document 拼接无法走 variables）；
 * 数值实参（number/Int）直接内插。返回值不含外层 query 头，用 aliasQueryDocument 包裹。
 */

/**
 * GraphQL 字符串字面量转义。
 * 覆盖反斜杠、双引号、换行（替换为空格保持单行）与回车；
 * GraphQL document 内插只用双引号字符串字面量，单引号无需处理。
 */
export function escapeGraphQLString(value: string): string {
  return value.replace(/\\/g, '\\\\').replace(/"/g, '\\"')
    .replace(/\n/g, ' ').replace(/\r/g, ' ');
}

/** 字段具名实参：value 为 string 时转义加引号，number 直接内插 */
export interface AliasArg {
  name: string;
  value: string | number;
}

/**
 * 构造单条 alias 字段：alias: field(name1: "v1", name2: 2) { inner }
 * 字符串实参自动转义加引号；数值实参直接内插。
 */
export function aliasField(alias: string, field: string, args: AliasArg[], inner: string): string {
  const rendered: string[] = [];
  for (const a of args) {
    rendered.push(typeof a.value === 'number'
      ? `${a.name}: ${a.value}`
      : `${a.name}: "${escapeGraphQLString(a.value)}"`);
  }
  return `${alias}: ${field}(${rendered.join(', ')}) { ${inner} }`;
}

/** 把多条 alias 字段包成完整 query document（opName 允许为空：匿名 query） */
export function aliasQueryDocument(opName: string, parts: string[]): string {
  const head = opName !== '' ? `query ${opName}` : 'query';
  return `${head} {\n  ${parts.join('\n  ')}\n}`;
}
