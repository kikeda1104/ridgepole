describe 'Ridgepole::Client#diff -> migrate' do
  let(:actual_dsl) {
    erbh(<<-EOS)
      create_table "employees", id: :integer, unsigned: true, force: :cascade do |t|
      end
    EOS
  }

  before { subject.diff(actual_dsl).migrate }
  subject { client(allow_pk_change: allow_pk_change) }

  context 'when allow_pk_change option is false' do
    let(:allow_pk_change) { false }
    let(:expected_dsl) {
      erbh(<<-EOS)
        create_table "employees", id: :bigint, unsigned: true, force: :cascade do |t|
        end
      EOS
    }

    it {
      expect(Ridgepole::Logger.instance).to receive(:warn).with(<<-EOS)
[WARNING] Primary key definition of `employees` differ but `allow_pk_change` option is false
  from: {:id=>:integer, :unsigned=>true}
    to: {:id=>:bigint, :unsigned=>true}
      EOS

      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_falsey
      delta.migrate
      expect(subject.dump).to match_fuzzy actual_dsl
    }
  end

  context 'when allow_pk_change option is false' do
    let(:allow_pk_change) { true }
    let(:expected_dsl) {
      erbh(<<-EOS)
        create_table "employees", id: :bigint, unsigned: true, force: :cascade do |t|
        end

        create_table "salaries", force: :cascade do |t|
          t.bigint "employee_id", null: false, unsigned: true
          t.index ["employee_id"], name: "fk_salaries_employees", <%= i cond(5.0, using: :btree) %>
        end
        add_foreign_key "salaries", "employees", name: "fk_salaries_employees"
      EOS
    }

    it {
      delta = subject.diff(expected_dsl)
      expect(delta.differ?).to be_truthy
      delta.migrate
      expect(subject.dump).to match_fuzzy expected_dsl
    }
  end
end
