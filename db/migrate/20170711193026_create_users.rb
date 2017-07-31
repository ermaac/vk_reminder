class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.string :access_token
      t.string :fullname
      t.string :photo_url
      t.integer :uid
    end
  end
end
