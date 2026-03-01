const String kMailSendMethodPrefKey = 'mail_send_method';
const String kMailSendMethodSmtp = 'smtp';
const String kMailSendMethodDeviceMailer = 'device_mailer';

String normalizeMailSendMethod(String? value) {
  if (value == kMailSendMethodDeviceMailer) {
    return kMailSendMethodDeviceMailer;
  }
  return kMailSendMethodSmtp;
}
