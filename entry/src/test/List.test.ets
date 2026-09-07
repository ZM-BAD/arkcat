/**
 * Local Test 注册文件（List.test.ets，测试执行器入口）。
 * 用例在 ./UtPureLogicTest.test —— 纯函数/模型映射层（与宿主 node:test 同域子集，
 * 意义：官方 ArkTS 语义执行 + 覆盖率）。
 */
import { UtPureLogicTest } from './UtPureLogicTest.test.ets';

export default function testsuite() {
  UtPureLogicTest();
}
