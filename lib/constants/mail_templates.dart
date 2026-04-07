const String kMailPlaceholderFilename = '{{FILENAME}}';
const String kMailPlaceholderHash = '{{HASH}}';
const String kMailPlaceholderCompanyName = '{{COMPANY_NAME}}';
const String kMailPlaceholderCompanyEmail = '{{COMPANY_EMAIL}}';
const String kMailPlaceholderCompanyTel = '{{COMPANY_TEL}}';
const String kMailPlaceholderCompanyAddress = '{{COMPANY_ADDRESS}}';
const String kMailPlaceholderCompanyReg = '{{COMPANY_REG}}';
const String kMailPlaceholderStaffName = '{{STAFF_NAME}}';
const String kMailPlaceholderStaffEmail = '{{STAFF_EMAIL}}';
const String kMailPlaceholderStaffMobile = '{{STAFF_MOBILE}}';
const String kMailPlaceholderBankAccounts = '{{BANK_ACCOUNTS}}';
const String kMailPlaceholderAccountsList = '{{ACCOUNTS}}';
const String kMailPlaceholderDocumentTypeName = '{{DOCUMENT_TYPE_NAME}}';

const String kMailTemplateIdDefault = 'default';
const String kMailTemplateIdNone = 'none';

const String kMailHeaderTemplateKey = 'mail_header_template';
const String kMailFooterTemplateKey = 'mail_footer_template';
const String kMailHeaderTextKey = 'mail_header_text';
const String kMailFooterTextKey = 'mail_footer_text';

const String kMailHeaderTemplateDefault = '【$kMailPlaceholderDocumentTypeName送付のお知らせ】\nファイル名: $kMailPlaceholderFilename\nHASH: $kMailPlaceholderHash';
const String kMailFooterTemplateDefault =
    '---\n$kMailPlaceholderCompanyName\n$kMailPlaceholderCompanyAddress\nTEL: $kMailPlaceholderCompanyTel / MAIL: $kMailPlaceholderCompanyEmail\n担当: $kMailPlaceholderStaffName ($kMailPlaceholderStaffMobile) $kMailPlaceholderStaffEmail\n$kMailPlaceholderBankAccounts\n登録番号: $kMailPlaceholderCompanyReg\nファイル名: $kMailPlaceholderFilename\nHASH: $kMailPlaceholderHash';

String applyMailTemplate(String template, Map<String, String> values) {
  var result = template;
  values.forEach((placeholder, value) {
    result = result.replaceAll(placeholder, value);
  });
  return result;
}
