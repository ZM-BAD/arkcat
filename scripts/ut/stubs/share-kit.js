// 宿主 UT 桩：@kit.ShareKit（utils/Share 仅在被测纯函数之外引用其 API）
export const systemShare = {
  SharePreviewMode: { DEFAULT: 0, DETAIL: 1 },
  SelectionMode: { SINGLE: 0, BATCH: 1 },
  SharedData: class {
    constructor(record) {
      this.record = record;
    }
  },
  ShareController: class {
    constructor(data) {
      this.data = data;
    }
    show() {
      return Promise.resolve();
    }
  }
};
