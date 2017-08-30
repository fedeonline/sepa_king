# encoding: utf-8
module SEPA
  class CreditorAccount < Account
    attr_accessor :abi, :creditor_identifier, :creditor_issuer

    validates_length_of :abi, within: 1..35
    validates_length_of :creditor_issuer, within: 1..35

    validates_with CreditorIdentifierValidator, message: "%{value} is invalid"
  end
end
