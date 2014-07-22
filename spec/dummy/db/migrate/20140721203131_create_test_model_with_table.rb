class CreateTestModelWithTable < ActiveRecord::Migration
  def change
    create_table :test_model_with_tables do |t|
      t.string :foo
    end
  end
end
