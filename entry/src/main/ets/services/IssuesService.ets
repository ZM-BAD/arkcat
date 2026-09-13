/**
 * Issues 列表服务（Spec 007）。
 * Label 筛选按 Spec 边界：GraphQL labels 参数为单选 [name]，多选客户端二次过滤。
 * Author/Assignee 走服务端 filterBy（实测 supported：createdBy/assignee，2026-09-13 起不再客户端过滤）。
 */
import { graphql } from './GitHttpClient';
import { IssuesPage, mapIssuesPage } from '../models/IssuesModels';

const ISSUES_QUERY = `
query IssuesList(
  $owner: String!, $name: String!,
  $states: [IssueState!] = [OPEN],
  $orderBy: IssueOrder = { field: CREATED_AT, direction: DESC },
  $first: Int = 25, $after: String, $label: [String!], $filterBy: IssueFilters
) {
  repository(owner: $owner, name: $name) {
    issues(states: $states, orderBy: $orderBy, first: $first, after: $after, labels: $label,
      filterBy: $filterBy) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state createdAt
        author { login }
        labels(first: 5) { nodes { name color } }
        milestone { title }
        comments { totalCount }
        assignees(first: 10) { nodes { login } }
        timelineItems(itemTypes: [CROSS_REFERENCED_EVENT], first: 5) {
          nodes { ... on CrossReferencedEvent { source { ... on PullRequest { number } } } }
        }
      }
    }
    labels(first: 30) { nodes { name } }
  }
}`;

/** GraphQL IssueOrder 变量结构 */
interface IssueOrderInput {
  field: string;
  direction: string;
}

/** 状态文本 → states 数组（Spec 027 官方四筛选：all/open/closed） */
export function repoIssueStates(state: string): string[] {
  if (state === 'open') {
    return ['OPEN'];
  }
  if (state === 'closed') {
    return ['CLOSED'];
  }
  return ['OPEN', 'CLOSED'];
}

/**
 * 排序键 → GraphQL IssueOrder（键集与工作区 Sort 一致；reactions 键 repository.issues
 * 无对应 orderBy，不进本页排序面板）。
 */
export function repoIssueOrder(sortKey: string): IssueOrderInput {
  if (sortKey === 'oldest') {
    return { 'field': 'CREATED_AT', 'direction': 'ASC' };
  }
  if (sortKey === 'most_commented') {
    return { 'field': 'COMMENTS', 'direction': 'DESC' };
  }
  if (sortKey === 'least_commented') {
    return { 'field': 'COMMENTS', 'direction': 'ASC' };
  }
  if (sortKey === 'recently_updated') {
    return { 'field': 'UPDATED_AT', 'direction': 'DESC' };
  }
  if (sortKey === 'least_recently_updated') {
    return { 'field': 'UPDATED_AT', 'direction': 'ASC' };
  }
  return { 'field': 'CREATED_AT', 'direction': 'DESC' };
}

export class IssuesService {
  /**
   * 仓库内 Issue 列表（Spec 027）：状态集合 + Label + Author/Assignee（服务端 filterBy）+ 排序 + 游标。
   * filterBy 与 states/labels 正交，分页语义不变；sortKey 按 repoIssueOrder 映射服务端 orderBy。
   */
  static async fetchRepoIssues(token: string, owner: string, name: string,
    state: string, label: string, cursor: string, author: string = '',
    assignee: string = '', sortKey: string = 'newest'): Promise<IssuesPage> {
    const order: IssueOrderInput = repoIssueOrder(sortKey);
    const variables: Record<string, Object> = {
      'owner': owner,
      'name': name,
      'states': repoIssueStates(state),
      'orderBy': order,
      'first': 50
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    if (label !== '') {
      variables['label'] = [label];
    }
    const filterBy: Record<string, Object> = {};
    if (author !== '') {
      filterBy['createdBy'] = author;
    }
    if (assignee !== '') {
      filterBy['assignee'] = assignee;
    }
    if (author !== '' || assignee !== '') {
      variables['filterBy'] = filterBy;
    }
    const data = await graphql(ISSUES_QUERY, variables, token);
    return mapIssuesPage(data);
  }
}
