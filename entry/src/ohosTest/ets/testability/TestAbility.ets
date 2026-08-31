/**
 * 仪器测试入口 Ability：启动即运行 Hypium 测试套件。
 */
import UIAbility from '@ohos.app.ability.UIAbility';
import AbilityDelegatorRegistry from '@ohos.app.ability.abilityDelegatorRegistry';
import Want from '@ohos.app.ability.Want';
import AbilityConstant from '@ohos.app.ability.AbilityConstant';
import { Hypium } from '@ohos/hypium';
import testsuite from '../test/List.test';

export default class TestAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    const abilityDelegator = AbilityDelegatorRegistry.getAbilityDelegator();
    const abilityDelegatorArguments = AbilityDelegatorRegistry.getArguments();
    Hypium.hypiumTest(abilityDelegator, abilityDelegatorArguments, testsuite);
  }

  onDestroy(): void {
  }

  onWindowStageCreate(): void {
  }

  onWindowStageDestroy(): void {
  }

  onForeground(): void {
  }

  onBackground(): void {
  }
}
