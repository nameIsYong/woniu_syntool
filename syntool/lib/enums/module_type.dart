enum ModuleType {
    // 健康筛查
  kScreening('TaskIllnessScreeningDetail', '健康筛查'),
  // 健康档案
  kArchives('TaskArchivesDetail', '档案'),
  // 高血压随访
  kHypertension('TaskFollowUpHypertensionDetail', '高血压随访'),
  // 糖尿病随访
  kDiabetes('TaskFollowUpDiabetesDetail', '糖尿病随访'),
  // 高糖合并
  kHSM('TaskFollowUpHSMDetail', '高糖合并随访'),
  // 高血压专案
  kCaseHyp('TaskChronicHypDetail', '高血压专案'),
  // 糖尿病专案
  kCaseDia('TaskChronicDiaDetail', '糖尿病专案'),
  // 中医辨识随访
  kTCM('TaskFollowUpTCMDetail', '中医辨识'),
  // 健康体检
  kPhysical('TaskFollowUpPhysicalDetail', '健康体检'),
  // 健康教育
  // kEdu('TaskHealthEduDetail', '健康教育'),
  //签约
  kSign('TaskSignDetail', '签约'),
  // 未知类型
  kUnknown('none', '未知类型');

  const ModuleType(this.value, this.displayName);
  final String value;
  final String displayName;
}