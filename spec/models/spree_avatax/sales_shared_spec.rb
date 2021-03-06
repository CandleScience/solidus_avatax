require 'spec_helper'

describe SpreeAvatax::SalesShared do

  describe '.reset_tax_attributes' do
    subject do
      SpreeAvatax::SalesShared.reset_tax_attributes(order)
    end

    let(:order) do
      create(:order_with_line_items,
        line_items_count: 1, # quantity set to 2 below
        line_items_price: 3,
        shipment_cost: 5,
      )
    end
    let(:line_item) { order.line_items.first }
    let(:shipment) { order.shipments.first }

    before do
      line_item.update_attributes!(quantity: 2)

      line_item.adjustments.eligible.tax.additional.create!({
        adjustable: line_item,
        amount: 1.23,
        order: order,
        label: 'Previous Tax',
        included: false,
        state: 'closed'
      })

      line_item.update_attributes!({
        additional_tax_total: 1,
        adjustment_total: 1,
        pre_tax_amount: 1,
        included_tax_total: 1,
      })
    end

    context 'when order is completed' do
      before do
        order.update_attributes!(completed_at: Time.now)
      end

      it 'should leave adjustments in place' do
        subject
        expect(line_item.adjustments.tax.count).to eq 1
      end
    end

    it 'should remove all eligible tax adjustments' do
      subject
      expect(line_item.adjustments.tax.count).to eq 0
    end

    it 'sets pre_tax_amount to discounted_amount' do
      subject
      expect(line_item.reload.pre_tax_amount).to eq(2 * 3)
      expect(shipment.reload.pre_tax_amount).to eq(5)
    end

    context 'when a SalesInvoice record is present' do
      let!(:sales_invoice) { create(:avatax_sales_invoice, order: order) }

      it 'deletes the SalesInvoice record if present' do
        subject
        expect(order.reload.avatax_sales_invoice).to eq(nil)
      end

      context 'when the SalesInvoice is committed' do
        before do
          sales_invoice.update!(committed_at: Time.now)
        end

        it 'raises without clearing anything' do
          expect {
            subject
          }.to raise_error(SpreeAvatax::SalesInvoice::AlreadyCommittedError)

          expect(line_item.adjustments.tax.count).to eq(1)
        end
      end
    end
  end
end
