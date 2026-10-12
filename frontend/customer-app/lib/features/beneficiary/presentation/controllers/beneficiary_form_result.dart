sealed class BeneficiaryFormResult {
  const BeneficiaryFormResult();
}

class BeneficiaryFormSaved extends BeneficiaryFormResult {
  const BeneficiaryFormSaved(this.id);
  final String id;
}

class BeneficiaryFormMessage extends BeneficiaryFormResult {
  const BeneficiaryFormMessage(this.message);
  final String message;
}

class BeneficiaryFormIgnored extends BeneficiaryFormResult {
  const BeneficiaryFormIgnored();
}
