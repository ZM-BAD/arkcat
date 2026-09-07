/**
 * Explore 筛选面板的语言常量（Spec 056 收口）。
 *
 * 说明：官方 App 的 Language/Spoken language 列表来自 GitHub 内部端点（无公开 API），
 * 此处内置常见子集近似。语言颜色来自 linguist 官方 colors.json（同 LanguageColors 来源）。
 *
 * 注意：本文件是 check-hardcoded-colors.py 的豁免白名单（数据色板），
 * 页面/组件里禁止直接引用色值，只允许引用本文件导出的常量。
 */

/** 编程语言（可用于 Language 筛选；name 与 GitHub search 的 language: qualifier 一致） */
export interface ExploreLanguage {
  name: string;
  color: string;
}

export const PROGRAM_LANGUAGES: ExploreLanguage[] = [
  { name: 'Assembly', color: '#6E4C13' },
  { name: 'Batchfile', color: '#C1F12E' },
  { name: 'C', color: '#555555' },
  { name: 'C#', color: '#178600' },
  { name: 'C++', color: '#F34B7D' },
  { name: 'Clojure', color: '#DB5855' },
  { name: 'CSS', color: '#563D7C' },
  { name: 'Dart', color: '#00B4AB' },
  { name: 'Dockerfile', color: '#384D54' },
  { name: 'Elixir', color: '#6E4A7E' },
  { name: 'Elm', color: '#60B5CC' },
  { name: 'Erlang', color: '#B83998' },
  { name: 'F#', color: '#B845FC' },
  { name: 'Go', color: '#00ADD8' },
  { name: 'Haskell', color: '#5E5086' },
  { name: 'HTML', color: '#E34C26' },
  { name: 'Java', color: '#B07219' },
  { name: 'JavaScript', color: '#F1E05A' },
  { name: 'JSON', color: '#292929' },
  { name: 'Julia', color: '#A270BA' },
  { name: 'Kotlin', color: '#A97BFF' },
  { name: 'Lua', color: '#000080' },
  { name: 'Makefile', color: '#427819' },
  { name: 'Nix', color: '#7E7EFF' },
  { name: 'OCaml', color: '#3BE133' },
  { name: 'Objective-C', color: '#438EFF' },
  { name: 'Perl', color: '#0298C3' },
  { name: 'PHP', color: '#4F5D95' },
  { name: 'PowerShell', color: '#012456' },
  { name: 'Python', color: '#3572A5' },
  { name: 'R', color: '#198CE7' },
  { name: 'Ruby', color: '#701516' },
  { name: 'Rust', color: '#DEA584' },
  { name: 'Scala', color: '#C22D40' },
  { name: 'SCSS', color: '#C6538C' },
  { name: 'Shell', color: '#89E051' },
  { name: 'Solidity', color: '#AA6746' },
  { name: 'Svelte', color: '#FF3E00' },
  { name: 'Swift', color: '#F05138' },
  { name: 'TypeScript', color: '#3178C6' },
  { name: 'Vue', color: '#41B883' },
  { name: 'Zig', color: '#EC915C' }
];

/** 口语语言（官方列表为 ISO 语言名全集，此处内置常见子集；qualifier=spoken_language:） */
export const SPOKEN_LANGUAGES: string[] = [
  'Abkhazian', 'Afar', 'Afrikaans', 'Akan', 'Albanian', 'Amharic', 'Arabic',
  'Aragonese', 'Armenian', 'Assamese', 'Azerbaijani', 'Basque', 'Belarusian',
  'Bengali', 'Bosnian', 'Bulgarian', 'Catalan', 'Chechen', 'Chinese', 'Croatian',
  'Czech', 'Danish', 'Dutch', 'English', 'Estonian', 'Finnish', 'French',
  'Galician', 'Georgian', 'German', 'Greek', 'Gujarati', 'Hebrew', 'Hindi',
  'Hungarian', 'Icelandic', 'Indonesian', 'Irish', 'Italian', 'Japanese',
  'Kannada', 'Korean', 'Lithuanian', 'Maltese', 'Marathi', 'Norwegian', 'Persian',
  'Polish', 'Portuguese', 'Romanian', 'Russian', 'Serbian', 'Slovak', 'Slovenian',
  'Spanish', 'Swedish', 'Tamil', 'Telugu', 'Thai', 'Turkish', 'Ukrainian', 'Urdu',
  'Vietnamese', 'Welsh'
];

/** 按语言名取色（查表，取代 LANAGUAGE_COLORS 14 项子集；未知语言回 ''） */
export function programLanguageColor(name: string): string {
  for (const lang of PROGRAM_LANGUAGES) {
    if (lang.name === name) {
      return lang.color;
    }
  }
  return '';
}
