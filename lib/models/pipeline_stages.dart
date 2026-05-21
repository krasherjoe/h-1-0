import 'project_model.dart';

/// 販売案件のパイプラインステージ
const kSalesStages = [
  '見積',
  '受注',
  '発注',
  '発送',
  '着荷確認',
  '請求',
  '入金済',
];

/// 開発案件のパイプラインステージ
const kDevStages = [
  '提案',
  '契約',
  '要件定義',
  '設計',
  '開発中',
  'テスト',
  '検収',
  '請求',
  '入金済',
];

/// 案件種別からステージリストを取得
List<String> stagesFor(ProjectType type) {
  switch (type) {
    case ProjectType.sales:
      return kSalesStages;
    case ProjectType.development:
      return kDevStages;
    case ProjectType.other:
      return kSalesStages;
  }
}

/// ステージが「完了」扱い（入金済）かどうか
bool isTerminalStage(String stage) => stage == '入金済';
