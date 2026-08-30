/**
 * Issues 列表服务（Spec 007）。
 * Label 筛选按 Spec 边界：GraphQL labels 参数为单选 [name]，多选客户端二次过滤。
 */
import { graphql } from './GitHttpClient';
import { IssuesPage, issueOrderField, mapIssuesPage } from '../models/IssuesModels';

const ISSUES_QUERY = `
query IssuesList(
  $owner: String!, $name: String!,
  $states: [IssueState!] = [OPEN],
  $orderBy: IssueOrder = { field: CREATED_AT, direction: DESC },
  $first: Int = 25, $after: String, $label: [String!]
) {
  repository(owner: $owner, name: $name) {
    issues(states: $states, orderBy: $orderBy, first: $first, after: $after, labels: $label) {
      totalCount
      pageInfo { hasNextPage endCursor }
      nodes {
        id number title state createdAt
        author { login }
        labels(first: 5) { nodes { name color } }
        comments { totalCount }
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

export class IssuesService {
  /** 拉取 Issue 列表页 */
  static async fetchIssues(token: string, owner: string, name: string, closed: boolean,
    sort: string, label: string, cursor: string): Promise<IssuesPage> {
    const order: IssueOrderInput = { 'field': issueOrderField(sort), 'direction': 'DESC' };
    const variables: Record<string, Object> = {
      'owner': owner,
      'name': name,
      'states': closed ? ['CLOSED'] : ['OPEN'],
      'orderBy': order,
      'first': 25
    };
    if (cursor !== '') {
      variables['after'] = cursor;
    }
    if (label !== '') {
      variables['label'] = [label];
    }
    const data = await graphql(ISSUES_QUERY, variables, token);
    return mapIssuesPage(data);
  }
}
