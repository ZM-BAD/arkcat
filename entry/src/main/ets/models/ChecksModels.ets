/**
 * Spec 048 Checks 模型与纯函数：Actions REST job/run 映射、时长文本、结论分档与副标题 key。
 * GraphQL 侧行模型复用 RepoSubModels.StatusCheckItem（rollup 预览与全量页同一行结构）。
 * 纯函数集中本文件供宿主单测（scripts/ut）。
 */
import { Json, JsonMap } from '../utils/Json';

/** 单个 job 步骤（REST /actions/jobs/{id} 的 steps[]；时间为 ISO 原文，展示层转时长） */
export interface JobStep {
  number: number;
  name: string;
  status: string;
  conclusion: string;
  startedAt: string;
  completedAt: string;
}

/** REST job 详情（步骤列表 + run 关联 + 官方页链接） */
export interface JobDetail {
  id: number;
  /** workflow run id（弹层 run 级重跑与头部 #run_number 懒取用） */
  runId: number;
  name: string;
  status: string;
  conclusion: string;
  startedAt: string;
  completedAt: string;
  /** 官方 job 页（share / Open in GitHub） */
  htmlUrl: string;
  steps: JobStep[];
}

/** workflow run 概要（弹层头部 `workflow 名 #run_number`） */
export interface RunInfo {
  name: string;
  runNumber: number;
}

/** 结论分档（区块头三档：失败/进行中/成功） */
export type CheckGroupKey = 'failed' | 'progress' | 'success';

/** 分档区块头（计数 + key 供选词） */
export interface CheckGroup {
  key: CheckGroupKey;
  count: number;
}

/**
 * 行状态 → 分档。终态灰类（CANCELLED/SKIPPED/NEUTRAL）不算成败，归入 progress 档呈现；
 * StatusContext 的 EXPECTED/PENDING 同样按未完对待。
 */
export function checkGroupKey(state: string): CheckGroupKey {
  if (state === 'SUCCESS') {
    return 'success';
  }
  if (state === 'FAILURE' || state === 'TIMED_OUT' || state === 'STARTUP_FAILURE') {
    return 'failed';
  }
  return 'progress';
}

/** 组区块序：失败优先可见，其次进行中，成功殿后（官方全成功截图即单组） */
const GROUP_ORDER: CheckGroupKey[] = ['failed', 'progress', 'success'];

/** 行状态集合 → 非空分档序列（按展示序），供 Checks 页区块头计数 */
export function groupChecks(states: string[]): CheckGroup[] {
  const counts = new Map<CheckGroupKey, number>();
  for (const s of states) {
    const key = checkGroupKey(s);
    counts.set(key, (counts.get(key) ?? 0) + 1);
  }
  const out: CheckGroup[] = [];
  for (const key of GROUP_ORDER) {
    const count = counts.get(key);
    if (count !== undefined && count > 0) {
      out.push({ key: key, count: count });
    }
  }
  return out;
}

/**
 * 时长文本（官方副标题「Successful in 47s」的时长段口径）：
 * <60s → `47s`；<1h → `2m 30s`；否则 `1h 05m`。缺起止（进行中/非法）返回空串。
 */
export function durationText(startedAt: string, completedAt: string): string {
  const start = Date.parse(startedAt);
  const end = Date.parse(completedAt);
  if (Number.isNaN(start) || Number.isNaN(end) || end < start) {
    return '';
  }
  const total = Math.max(0, Math.round((end - start) / 1000));
  if (total < 60) {
    return `${total}s`;
  }
  const mm = Math.floor(total / 60);
  if (mm < 60) {
    const ss = total % 60;
    return `${mm}m ${ss < 10 ? '0' : ''}${ss}s`;
  }
  const hh = Math.floor(mm / 60);
  const rem = mm % 60;
  return `${hh}h ${rem < 10 ? '0' : ''}${rem}m`;
}

/**
 * 行状态 → 副标题文案 key 后缀（conclusion 优先，进行中回落 status，由调用方归一后传入）：
 * success / failed / cancelled / waiting / progress / action；未知状态按进行中灰态（不误报成败）。
 */
export function conclusionKey(state: string): string {
  switch (state) {
    case 'SUCCESS':
      return 'success';
    case 'FAILURE':
    case 'TIMED_OUT':
    case 'STARTUP_FAILURE':
      return 'failed';
    case 'CANCELLED':
    case 'SKIPPED':
    case 'NEUTRAL':
      return 'cancelled';
    case 'QUEUED':
    case 'WAITING':
    case 'PENDING':
    case 'REQUESTED':
    case 'EXPECTED':
    case 'STALE':
      return 'waiting';
    case 'ACTION_REQUIRED':
      return 'action';
    case 'IN_PROGRESS':
      return 'progress';
    default:
      return 'progress';
  }
}

/** REST /repos/{o}/{r}/actions/jobs/{id} 响应 → JobDetail（steps 按 number 升序；缺失容错为空） */
export function mapRestJob(raw: JsonMap): JobDetail {
  const steps: JobStep[] = [];
  for (const nodeItem of Json.arr(raw, 'steps')) {
    const node = nodeItem as JsonMap;
    steps.push({
      number: Json.num(node, 'number'),
      name: Json.str(node, 'name'),
      status: Json.str(node, 'status'),
      conclusion: Json.str(node, 'conclusion'),
      startedAt: Json.str(node, 'started_at'),
      completedAt: Json.str(node, 'completed_at')
    });
  }
  steps.sort((a: JobStep, b: JobStep) => a.number - b.number);
  return {
    id: Json.num(raw, 'id'),
    runId: Json.num(raw, 'run_id'),
    name: Json.str(raw, 'name'),
    status: Json.str(raw, 'status'),
    conclusion: Json.str(raw, 'conclusion'),
    startedAt: Json.str(raw, 'started_at'),
    completedAt: Json.str(raw, 'completed_at'),
    htmlUrl: Json.str(raw, 'html_url'),
    steps: steps
  };
}

/** REST /repos/{o}/{r}/actions/runs/{id} 响应 → RunInfo */
export function mapRestRun(raw: JsonMap): RunInfo {
  return { name: Json.str(raw, 'name'), runNumber: Json.num(raw, 'run_number') };
}
