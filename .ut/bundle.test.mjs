var ObservedV2 = function () { }; var Trace = function () { };
var __create = Object.create;
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __knownSymbol = (name, symbol) => (symbol = Symbol[name]) ? symbol : Symbol.for("Symbol." + name);
var __typeError = (msg) => {
  throw TypeError(msg);
};
var __defNormalProp = (obj, key, value) => key in obj ? __defProp(obj, key, { enumerable: true, configurable: true, writable: true, value }) : obj[key] = value;
var __name = (target, value) => __defProp(target, "name", { value, configurable: true });
var __decoratorStart = (base) => [, , , __create(base?.[__knownSymbol("metadata")] ?? null)];
var __decoratorStrings = ["class", "method", "getter", "setter", "accessor", "field", "value", "get", "set"];
var __expectFn = (fn) => fn !== void 0 && typeof fn !== "function" ? __typeError("Function expected") : fn;
var __decoratorContext = (kind, name, done, metadata, fns) => ({ kind: __decoratorStrings[kind], name, metadata, addInitializer: (fn) => done._ ? __typeError("Already initialized") : fns.push(__expectFn(fn || null)) });
var __decoratorMetadata = (array, target) => __defNormalProp(target, __knownSymbol("metadata"), array[3]);
var __runInitializers = (array, flags, self, value) => {
  for (var i = 0, fns = array[flags >> 1], n = fns && fns.length; i < n; i++) flags & 1 ? fns[i].call(self) : value = fns[i].call(self, value);
  return value;
};
var __decorateElement = (array, flags, name, decorators, target, extra) => {
  var fn, it, done, ctx, access, k = flags & 7, s = !!(flags & 8), p = !!(flags & 16);
  var j = k > 3 ? array.length + 1 : k ? s ? 1 : 2 : 0, key = __decoratorStrings[k + 5];
  var initializers = k > 3 && (array[j - 1] = []), extraInitializers = array[j] || (array[j] = []);
  var desc = k && (!p && !s && (target = target.prototype), k < 5 && (k > 3 || !p) && __getOwnPropDesc(k < 4 ? target : { get [name]() {
    return __privateGet(this, extra);
  }, set [name](x) {
    return __privateSet(this, extra, x);
  } }, name));
  k ? p && k < 4 && __name(extra, (k > 2 ? "set " : k > 1 ? "get " : "") + name) : __name(target, name);
  for (var i = decorators.length - 1; i >= 0; i--) {
    ctx = __decoratorContext(k, name, done = {}, array[3], extraInitializers);
    if (k) {
      ctx.static = s, ctx.private = p, access = ctx.access = { has: p ? (x) => __privateIn(target, x) : (x) => name in x };
      if (k ^ 3) access.get = p ? (x) => (k ^ 1 ? __privateGet : __privateMethod)(x, target, k ^ 4 ? extra : desc.get) : (x) => x[name];
      if (k > 2) access.set = p ? (x, y) => __privateSet(x, target, y, k ^ 4 ? extra : desc.set) : (x, y) => x[name] = y;
    }
    it = (0, decorators[i])(k ? k < 4 ? p ? extra : desc[key] : k > 4 ? void 0 : { get: desc.get, set: desc.set } : target, ctx), done._ = 1;
    if (k ^ 4 || it === void 0) __expectFn(it) && (k > 4 ? initializers.unshift(it) : k ? p ? extra = it : desc[key] = it : target = it);
    else if (typeof it !== "object" || it === null) __typeError("Object expected");
    else __expectFn(fn = it.get) && (desc.get = fn), __expectFn(fn = it.set) && (desc.set = fn), __expectFn(fn = it.init) && initializers.unshift(fn);
  }
  return k || __decoratorMetadata(array, target), desc && __defProp(target, name, desc), p ? k ^ 4 ? extra : desc : target;
};
var __publicField = (obj, key, value) => __defNormalProp(obj, typeof key !== "symbol" ? key + "" : key, value);
var __accessCheck = (obj, member, msg) => member.has(obj) || __typeError("Cannot " + msg);
var __privateIn = (member, obj) => Object(obj) !== obj ? __typeError('Cannot use the "in" operator on this value') : member.has(obj);
var __privateGet = (obj, member, getter) => (__accessCheck(obj, member, "read from private field"), getter ? getter.call(obj) : member.get(obj));
var __privateSet = (obj, member, value, setter) => (__accessCheck(obj, member, "write to private field"), setter ? setter.call(obj, value) : member.set(obj, value), value);
var __privateMethod = (obj, member, method) => (__accessCheck(obj, member, "access private method"), method);

// scripts/ut/unit.test.ts
import { test } from "node:test";
import assert from "node:assert/strict";

// entry/src/main/ets/utils/Json.ets
var Json = class {
  /** 读取字符串字段，缺失或类型不符返回 fallback */
  static str(o, key, fallback = "") {
    const v = o[key];
    return typeof v === "string" ? v : fallback;
  }
  /** 读取数值字段，缺失或类型不符返回 fallback */
  static num(o, key, fallback = 0) {
    const v = o[key];
    return typeof v === "number" ? v : fallback;
  }
  /** 读取布尔字段，缺失或类型不符返回 fallback */
  static bool(o, key, fallback = false) {
    const v = o[key];
    return typeof v === "boolean" ? v : fallback;
  }
  /** 读取嵌套对象字段，缺失返回 null */
  static obj(o, key) {
    const v = o[key];
    return v !== null && v !== void 0 && typeof v === "object" ? v : null;
  }
  /** 读取数组字段，缺失返回空数组 */
  static arr(o, key) {
    const v = o[key];
    return Array.isArray(v) ? v : [];
  }
  /** 安全解析 JSON 文本，失败返回 null */
  static parse(text) {
    try {
      const parsed = JSON.parse(text);
      return parsed !== null && typeof parsed === "object" ? parsed : null;
    } catch (e) {
      return null;
    }
  }
};

// entry/src/main/ets/utils/Format.ets
var MINUTE_MS = 60 * 1e3;
var HOUR_MS = 60 * MINUTE_MS;
var DAY_MS = 24 * HOUR_MS;
function timeParts(iso, nowMs) {
  const ts = Date.parse(iso);
  if (Number.isNaN(ts)) {
    return null;
  }
  const diff = Math.max(0, nowMs - ts);
  if (diff < MINUTE_MS) {
    return { value: 0, unit: "just_now" };
  }
  if (diff < HOUR_MS) {
    return { value: Math.floor(diff / MINUTE_MS), unit: "minute" };
  }
  if (diff < DAY_MS) {
    return { value: Math.floor(diff / HOUR_MS), unit: "hour" };
  }
  const days = Math.floor(diff / DAY_MS);
  if (days <= 30) {
    return { value: days, unit: "day" };
  }
  const months = Math.floor(days / 30);
  if (months >= 12) {
    return { value: Math.floor(months / 12), unit: "year" };
  }
  return { value: months, unit: "month" };
}
function compactCount(n) {
  if (n < 1e3) {
    return `${n}`;
  }
  const k = Math.round(n / 100) / 10;
  return `${k}k`;
}
function githubShortTime(parts) {
  switch (parts.unit) {
    case "just_now":
      return "now";
    case "minute":
      return `${parts.value}m`;
    case "hour":
      return `${parts.value}h`;
    case "day":
      return `${parts.value}d`;
    case "month":
      return `${parts.value}mo`;
    case "year":
      return `${parts.value}y`;
  }
  return "";
}

// entry/src/main/ets/utils/Diff.ets
var HUNK_RE = /^@@ -([0-9]+)(?:,([0-9]+))? \+([0-9]+)(?:,([0-9]+))? @@/;
function parseHunkHeader(header) {
  const m = HUNK_RE.exec(header);
  if (m === null) {
    return { header, oldStart: 0, newStart: 0, lines: [] };
  }
  return {
    header,
    oldStart: Number(m[1] ?? "0"),
    newStart: Number(m[3] ?? "0"),
    lines: []
  };
}
function parseDiffPatch(patch) {
  if (patch === "") {
    return [];
  }
  const rawLines = patch.split("\n");
  const hunks = [];
  let current = null;
  let oldLine = 0;
  let newLine = 0;
  for (const raw of rawLines) {
    const line = raw.endsWith("\r") ? raw.substring(0, raw.length - 1) : raw;
    if (line.startsWith("@@")) {
      current = parseHunkHeader(line);
      if (current.oldStart > 0 || current.newStart > 0) {
        hunks.push(current);
        oldLine = current.oldStart - 1;
        newLine = current.newStart - 1;
        continue;
      }
      if (current.lines.length === 0) {
        current = null;
        continue;
      }
    }
    if (current === null) {
      continue;
    }
    if (line === "") {
      continue;
    }
    if (line.startsWith("\\")) {
      continue;
    }
    if (line.startsWith("+")) {
      newLine += 1;
      current.lines.push({ kind: "add", text: line.substring(1), oldLine: 0, newLine });
    } else if (line.startsWith("-")) {
      oldLine += 1;
      current.lines.push({ kind: "del", text: line.substring(1), oldLine, newLine: 0 });
    } else {
      oldLine += 1;
      newLine += 1;
      current.lines.push({ kind: "ctx", text: line.substring(1), oldLine, newLine });
    }
  }
  return hunks;
}
function fileBaseName(path) {
  const idx = path.lastIndexOf("/");
  return idx >= 0 ? path.substring(idx + 1) : path;
}

// node_modules/@kit.ArkData/index.js
var preferences = {
  getPreferences: () => Promise.resolve({}),
  getPreferencesSync: () => ({ getSync: () => null })
};

// entry/src/main/ets/utils/WorkConfig.ets
var WORK_SECTION_IDS = [
  "issues",
  "prs",
  "discussions",
  "projects",
  "topRepos",
  "orgs",
  "starred"
];
var PREFS_NAME = "work_prefs";
var PREFS_KEY = "work_sections_v1";
function defaultWorkSections() {
  const result = [];
  for (const id of WORK_SECTION_IDS) {
    result.push({ id, visible: true });
  }
  return result;
}
function workSectionsToStorage(sections) {
  return JSON.stringify(sections);
}
function workSectionsFromStorage(text) {
  try {
    const parsed = JSON.parse(text);
    if (!Array.isArray(parsed)) {
      return defaultWorkSections();
    }
    const result = [];
    const seen = /* @__PURE__ */ new Set();
    for (const raw of parsed) {
      const map = raw;
      const id = Json.str(map, "id");
      if (id !== "" && !seen.has(id) && WORK_SECTION_IDS.indexOf(id) >= 0) {
        seen.add(id);
        result.push({ id, visible: Json.bool(map, "visible", true) });
      }
    }
    return result.length > 0 ? result : defaultWorkSections();
  } catch (e) {
    return defaultWorkSections();
  }
}
var _sections_dec, _WorkConfigStore_decorators, _init;
_WorkConfigStore_decorators = [ObservedV2], _sections_dec = [Trace];
var _WorkConfigStore = class _WorkConfigStore {
  constructor() {
    __publicField(this, "sections", __runInitializers(_init, 8, this, defaultWorkSections())), __runInitializers(_init, 11, this);
  }
  /** 启动/进入编辑页时加载持久化配置（失败保持默认） */
  static async load(context) {
    if (context === void 0) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      const value = await prefs.get(PREFS_KEY, "");
      if (typeof value === "string") {
        _WorkConfigStore.instance.sections = workSectionsFromStorage(value);
      }
    } catch (e) {
    }
  }
  /** SAVE：持久化当前配置（失败静默，不阻断返回） */
  static async save(context) {
    if (context === void 0) {
      return;
    }
    try {
      const prefs = await preferences.getPreferences(context, PREFS_NAME);
      await prefs.put(PREFS_KEY, workSectionsToStorage(_WorkConfigStore.instance.sections));
      await prefs.flush();
    } catch (e) {
    }
  }
};
_init = __decoratorStart(null);
__decorateElement(_init, 5, "sections", _sections_dec, _WorkConfigStore);
_WorkConfigStore = __decorateElement(_init, 0, "WorkConfigStore", _WorkConfigStore_decorators, _WorkConfigStore);
__publicField(_WorkConfigStore, "instance", new _WorkConfigStore());
__runInitializers(_init, 1, _WorkConfigStore);
var WorkConfigStore = _WorkConfigStore;

// entry/src/main/ets/models/RepoSubModels.ets
function filterPrsByAuthor(prs, author) {
  const next = [];
  for (const pr of prs) {
    if (author === "" || pr.authorLogin === author) {
      next.push(pr);
    }
  }
  return next;
}
function repoPrIconKey(state, merged) {
  if (merged || state === "MERGED") {
    return "merged";
  }
  return state === "OPEN" ? "open" : "closed";
}
function mapRepoCommit(raw) {
  const author = Json.obj(raw, "author");
  const authorUser = author !== null ? Json.obj(author, "user") : null;
  const authorLogin = authorUser !== null && Json.str(authorUser, "login") !== "" ? Json.str(authorUser, "login") : author !== null ? Json.str(author, "name") : "";
  const checks = Json.obj(raw, "statusCheckRollup");
  return {
    oid: Json.str(raw, "oid"),
    headline: Json.str(raw, "messageHeadline"),
    committedDate: Json.str(raw, "committedDate"),
    authorLogin,
    authorAvatar: author !== null ? Json.str(author, "avatarUrl") : "",
    checksState: checks !== null ? Json.str(checks, "state") : ""
  };
}
function mapPrCommits(data) {
  const repo = Json.obj(data, "repository") ?? {};
  const pr = Json.obj(repo, "pullRequest") ?? {};
  const commitsConn = Json.obj(pr, "commits") ?? {};
  const pageInfo = Json.obj(commitsConn, "pageInfo");
  const commits = [];
  for (const nodeItem of Json.arr(commitsConn, "nodes")) {
    const commit = Json.obj(nodeItem, "commit");
    if (commit !== null) {
      commits.push(mapRepoCommit(commit));
    }
  }
  return {
    hasNextPage: pageInfo !== null ? Json.bool(pageInfo, "hasNextPage") : false,
    endCursor: pageInfo !== null ? Json.str(pageInfo, "endCursor") : "",
    commits
  };
}

// entry/src/main/ets/models/PrDiffModels.ets
function mapFileNode(node) {
  if (node === null || node === void 0) {
    return { path: "", additions: 0, deletions: 0, status: "", patch: "", hunks: [], diffTooLarge: false, expanded: false };
  }
  return {
    path: Json.str(node, "path"),
    additions: Json.num(node, "additions"),
    deletions: Json.num(node, "deletions"),
    status: Json.str(node, "status"),
    patch: "",
    hunks: [],
    diffTooLarge: false,
    expanded: false
  };
}
function mapPrFiles(data) {
  const repo = Json.obj(data, "repository") ?? {};
  const pr = Json.obj(repo, "pullRequest") ?? {};
  const files = Json.obj(pr, "files") ?? {};
  const nodes = [];
  for (const n of Json.arr(files, "nodes")) {
    nodes.push(mapFileNode(n));
  }
  return {
    totalCount: Json.num(files, "totalCount"),
    pullRequestId: Json.str(pr, "id"),
    additions: Json.num(pr, "additions"),
    deletions: Json.num(pr, "deletions"),
    files: nodes
  };
}

// scripts/ut/unit.test.ts
var NOW = Date.parse("2026-08-31T12:00:00Z");
var JsonMapType = new Json();
function json() {
  return { "a": "x", "n": 5, "b": true, "obj": { "k": "v" }, "arr": [1, 2] };
}
test("Json.str \u7F3A\u5931/\u7C7B\u578B\u4E0D\u7B26\u56DE\u9000\u9ED8\u8BA4", () => {
  assert.equal(Json.str(json(), "a"), "x");
  assert.equal(Json.str(json(), "missing"), "");
  assert.equal(Json.str(json(), "missing", "d"), "d");
  assert.equal(Json.str(json(), "n"), "");
});
test("Json.num/bool/obj/arr \u515C\u5E95", () => {
  assert.equal(Json.num(json(), "n"), 5);
  assert.equal(Json.num(json(), "a"), 0);
  assert.ok(Json.obj(json(), "obj") !== null);
  assert.equal(Json.obj(json(), "missing"), null);
  assert.equal(Json.arr(json(), "arr").length, 2);
  assert.equal(Json.arr(json(), "missing").length, 0);
});
test("timeParts \u5404\u6863\u4F4D", () => {
  assert.equal(timeParts("2026-08-31T11:59:50Z", NOW)?.unit, "just_now");
  assert.equal(timeParts("2026-08-31T11:55:00Z", NOW)?.value, 5);
  assert.equal(timeParts("2026-08-31T09:00:00Z", NOW)?.unit, "hour");
  assert.equal(timeParts("2026-08-01T12:00:00Z", NOW)?.unit, "day");
  assert.equal(timeParts("2026-05-31T12:00:00Z", NOW)?.value, 3);
  assert.equal(timeParts("2026-05-31T12:00:00Z", NOW)?.unit, "month");
  assert.equal(timeParts("2025-08-31T12:00:00Z", NOW)?.unit, "year");
  assert.equal(timeParts("bad-date", NOW), null);
});
test("githubShortTime \u77ED\u683C\u5F0F", () => {
  assert.equal(githubShortTime(timeParts("2026-08-31T09:00:00Z", NOW)), "3h");
  assert.equal(githubShortTime(timeParts("2026-08-30T12:00:00Z", NOW)), "1d");
  assert.equal(githubShortTime(timeParts("2026-08-31T11:59:50Z", NOW)), "now");
});
test("compactCount \u7F29\u7565\u8BA1\u6570", () => {
  assert.equal(compactCount(999), "999");
  assert.equal(compactCount(1500), "1.5k");
  assert.equal(compactCount(1e3), "1k");
  assert.equal(compactCount(12e3), "12k");
});
test("parseDiffPatch \u6807\u51C6 patch \u89E3\u6790", () => {
  const patch = "@@ -1,3 +1,4 @@\n ctx\n+added\n-del\n";
  const hunks = parseDiffPatch(patch);
  assert.equal(hunks.length, 1);
  const h = hunks[0];
  assert.equal(h.oldStart, 1);
  assert.equal(h.lines.filter((l) => l.kind === "add").length, 1);
  assert.equal(h.newStart, 1);
  assert.equal(h.lines.filter((l) => l.kind === "del").length, 1);
  assert.equal(h.lines.length, 3);
  assert.equal(h.lines[0].kind, "ctx");
  assert.equal(h.lines[1].kind, "add");
  assert.equal(h.lines[1].newLine, 2);
  assert.equal(h.lines[2].kind, "del");
  assert.equal(h.lines[2].oldLine, 2);
});
test("parseDiffPatch \u7A7A patch \u4E0E\u975E\u6CD5\u8F93\u5165", () => {
  assert.equal(parseDiffPatch("").length, 0);
  assert.equal(parseDiffPatch("not a patch").length, 0);
});
test("fileBaseName \u63D0\u53D6", () => {
  assert.equal(fileBaseName("/a/b/c.ts"), "c.ts");
  assert.equal(fileBaseName("README.md"), "README.md");
  assert.equal(fileBaseName("src/main/ets/Index.ets"), "Index.ets");
});
test("WorkConfig \u9ED8\u8BA4\u5206\u533A\u4E0E roundtrip", () => {
  const defaults = defaultWorkSections();
  assert.ok(defaults.length >= 7);
  const storage = workSectionsToStorage(defaults);
  const restored = workSectionsFromStorage(storage);
  assert.equal(restored.length, defaults.length);
  assert.equal(restored[0].id, defaults[0].id);
});
test("mapRepoCommit GitActor user \u515C\u5E95\uFF08\u65E0\u5173\u8054\u8D26\u53F7\u7528 name\uFF09", () => {
  const raw = {
    "oid": "abc123",
    "messageHeadline": "fix: something",
    "committedDate": "2026-08-31T10:00:00Z",
    "author": { "name": "\u5468\u94ED", "avatarUrl": "" },
    "statusCheckRollup": { "state": "SUCCESS" }
  };
  const item = mapRepoCommit(raw);
  assert.equal(item.authorLogin, "\u5468\u94ED");
  assert.equal(item.checksState, "SUCCESS");
  const raw2 = {
    "oid": "def456",
    "messageHeadline": "hi",
    "committedDate": "2026-08-31T10:00:00Z",
    "author": { "name": "Zhang", "avatarUrl": "", "user": { "login": "zm-bad" } }
  };
  assert.equal(mapRepoCommit(raw2).authorLogin, "zm-bad");
});
test("repoPrIconKey \u72B6\u6001\u6620\u5C04", () => {
  assert.equal(repoPrIconKey("MERGED", true), "merged");
  assert.equal(repoPrIconKey("OPEN", false), "open");
  assert.equal(repoPrIconKey("CLOSED", false), "closed");
});
test("filterPrsByAuthor \u4F5C\u8005\u8FC7\u6EE4", () => {
  const prs = [
    { id: "1", repoName: "a", repoFullName: "o/a", number: 1, title: "t1", state: "OPEN", merged: false, labels: [], authorLogin: "alice" },
    { id: "2", repoName: "b", repoFullName: "o/b", number: 2, title: "t2", state: "CLOSED", merged: true, labels: [], authorLogin: "bob" }
  ];
  assert.equal(filterPrsByAuthor(prs, "alice").length, 1);
  assert.equal(filterPrsByAuthor(prs, "").length, 2);
});
test("mapPrCommits \u8282\u70B9\u89E3\u5305\uFF08PR commits \u9996\u4F8B\uFF09", () => {
  const data = {
    "repository": {
      "pullRequest": {
        "commits": {
          "pageInfo": { "hasNextPage": false, "endCursor": "" },
          "nodes": [
            { "commit": { "oid": "aa", "messageHeadline": "m1", "committedDate": "2026-08-31T10:00:00Z", "author": { "name": "N", "user": { "login": "u1" } }, "statusCheckRollup": { "state": "SUCCESS" } } },
            { "commit": { "oid": "bb", "messageHeadline": "m2", "committedDate": "2026-08-31T10:00:00Z", "author": { "name": "N2" } } }
          ]
        }
      }
    }
  };
  const page = mapPrCommits(data);
  assert.equal(page.commits.length, 2);
  assert.equal(page.commits[0].authorLogin, "u1");
  assert.equal(page.commits[0].checksState, "SUCCESS");
  assert.equal(page.commits[1].checksState, "");
});
test("mapPrFiles \u7EDF\u8BA1\u5B57\u6BB5\u4E0E\u6587\u4EF6\u5217\u8868", () => {
  const data = {
    "repository": {
      "pullRequest": {
        "id": "PRID",
        "additions": 12,
        "deletions": 3,
        "files": {
          "totalCount": 2,
          "nodes": [
            { "path": "a.ts", "additions": 10, "deletions": 0 },
            { "path": "b.ts", "additions": 2, "deletions": 3 }
          ]
        }
      }
    }
  };
  const page = mapPrFiles(data);
  assert.equal(page.totalCount, 2);
  assert.equal(page.additions, 12);
  assert.equal(page.deletions, 3);
  assert.equal(page.files.length, 2);
  assert.equal(page.files[0].path, "a.ts");
});
