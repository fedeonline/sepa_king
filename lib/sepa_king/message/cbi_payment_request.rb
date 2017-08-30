# encoding: utf-8

module SEPA
  class CBIPaymentRequest < Message
    self.account_class = CreditorAccount
    self.transaction_class = CreditTransferTransaction
    self.xml_main_tag = nil
    self.known_schemas = [ CBI_PARE_00_04_00 ]

    def to_xml(schema_name=self.known_schemas.first)
      # TODO: restore validation
      #raise RuntimeError.new(errors.full_messages.join("\n")) unless valid?
      #raise RuntimeError.new("Incompatible with schema #{schema_name}!") unless schema_compatible?(schema_name)

      builder = Builder::XmlMarkup.new indent: 2
      builder.instruct!
      builder.CBIPaymentRequest(xml_schema('CBI:xsd:CBIPaymentRequest.00.04.00')) do
        build_group_header(builder)
        build_payment_informations(builder)
      end
    end

    private
    # @return {Hash<Symbol=>String>} xml schema information used in output xml
    def xml_schema(schema_name)
      { :'xmlns:xs' => 'http://www.w3.org/2001/XMLSchema',
        :xmlns => "urn:#{schema_name}",
        :targetNamespace => "urn:#{schema_name}",
        :elementFormDefault => 'qualified'
      }
    end

    def build_group_header(builder)
      builder.GrpHdr do
        builder.MsgId(message_identification)
        builder.CreDtTm(Time.now.iso8601)
        builder.NbOfTxs(transactions.length)
        builder.CtrlSum('%.2f' % amount_total)
        builder.InitgPty do
          builder.Nm(account.name)
          builder.Id do
            builder.OrgId do
              builder.Othr do
                builder.Id(account.creditor_identifier)
                builder.Issr(account.creditor_issuer)
              end
            end
          end if account.respond_to? :creditor_identifier
        end
      end
    end

    # Find groups of transactions which share the same values of some attributes
    def transaction_group(transaction)
      { requested_date: transaction.requested_date,
        batch_booking:  transaction.batch_booking,
        service_level:  transaction.service_level
      }
    end

    def build_payment_informations(builder)
      # Build a PmtInf block for every group of transactions
      grouped_transactions.each do |group, transactions|
        # All transactions with the same requested_date are placed into the same PmtInf block
        builder.PmtInf do
          builder.PmtInfId(payment_information_identification(group))
          builder.PmtMtd('TRA')
          builder.PmtTpInf do
            builder.InstrPrty('NORM')
            builder.SvcLvl do
              builder.Cd(group[:service_level])
            end
          end
          builder.ReqdExctnDt(group[:requested_date].iso8601)
          builder.Dbtr do
            builder.Nm(account.name)
          end
          builder.DbtrAcct do
            builder.Id do
              builder.IBAN(account.iban)
            end
          end
          builder.DbtrAgt do
            builder.FinInstnId do
              builder.ClrSysMmbId do
                builder.MmbId(account.abi)
              end
            end
          end
          builder.ChrgBr('SLEV')

          transactions.each do |transaction|
            build_transaction(builder, transaction)
          end
        end
      end
    end

    def build_transaction(builder, transaction)
      builder.CdtTrfTxInf do
        builder.PmtId do
          if transaction.instruction.present?
            builder.InstrId(transaction.instruction)
          end
          builder.EndToEndId(transaction.reference)
        end
        builder.PmtTpInf do
          builder.CtgyPurp do
            builder.Cd(transaction.category_purpose)
          end
        end
        builder.Amt do
          builder.InstdAmt('%.2f' % transaction.amount, Ccy: transaction.currency)
        end
        if transaction.bic
          builder.CdtrAgt do
            builder.FinInstnId do
              builder.BIC(transaction.bic)
            end
          end
        end
        builder.Cdtr do
          builder.Nm(transaction.name)
          builder.PstlAdr do
            builder.TwnNm(transaction.city)
          end
        end
        builder.CdtrAcct do
          builder.Id do
            builder.IBAN(transaction.iban)
          end
        end
        if transaction.remittance_information
          builder.RmtInf do
            builder.Ustrd(transaction.remittance_information)
          end
        end
      end
    end
  end
end
