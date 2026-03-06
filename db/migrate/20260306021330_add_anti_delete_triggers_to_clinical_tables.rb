class AddAntiDeleteTriggersToClinicalTables < ActiveRecord::Migration[8.1]
  # Tablas clínicas protegidas contra borrado físico (NOM-024-SSA3-2012)
  PROTECTED_TABLES = %w[progress_notes clinical_histories prescriptions informed_consents].freeze

  def up
    execute <<-SQL
      CREATE OR REPLACE FUNCTION prevent_hard_deletes()
      RETURNS TRIGGER AS $$
      BEGIN
        RAISE EXCEPTION
          'Prohibido por NOM-024-SSA3-2012: El borrado físico de registros médicos viola la '
          'retención obligatoria de 5 años establecida en NOM-004-SSA3-2012. '
          'Utilice borrado lógico actualizando discarded_at en lugar de DELETE.'
          USING ERRCODE = 'P0001';
        RETURN NULL;
      END;
      $$ LANGUAGE plpgsql;
    SQL

    PROTECTED_TABLES.each do |table|
      execute <<-SQL
        CREATE TRIGGER prevent_hard_deletes_on_#{table}
        BEFORE DELETE ON #{table}
        FOR EACH ROW
        EXECUTE FUNCTION prevent_hard_deletes();
      SQL
    end
  end

  def down
    PROTECTED_TABLES.each do |table|
      execute "DROP TRIGGER IF EXISTS prevent_hard_deletes_on_#{table} ON #{table};"
    end
    execute "DROP FUNCTION IF EXISTS prevent_hard_deletes();"
  end
end
