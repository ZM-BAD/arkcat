import TestRunner from '@ohos.application.testRunner';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

/**
 * Hypium 标准测试 Runner（module.json5 testRunner 指定入口）。
 * 走 aa test / hvigor onDeviceTest 时经本类 onRun 启动测试套件；
 * 裸 aa start 不经外层 testRunner 加载，由 TestAbility 套件入口启动（见 testability/TestAbility.ets）。
 */
export default class OpenHarmonyTestRunner implements TestRunner {
  onPrepare(): void {
    return;
  }

  onRun(): void {
    const abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
    const abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
  }
}
