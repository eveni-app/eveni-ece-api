namespace :catalogs do
  desc "Importa el catálogo CIE-10 desde un archivo CSV (columnas: code,description,category,chapter)"
  task import_cie10: :environment do |_, args|
    file_path = ENV["FILE"] || Rails.root.join("db", "seeds", "cie10.csv")
    unless File.exist?(file_path)
      puts "ERROR: Archivo no encontrado: #{file_path}"
      puts "Uso: rake catalogs:import_cie10 FILE=/ruta/al/cie10.csv"
      exit 1
    end

    require "csv"
    count = 0
    CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
      Cie10Diagnosis.find_or_create_by(code: row["code"]) do |d|
        d.description = row["description"]
        d.category    = row["category"]
        d.chapter     = row["chapter"]
      end
      count += 1
    end
    puts "CIE-10: #{count} diagnósticos importados/actualizados."
  end

  desc "Importa el Cuadro Básico de Medicamentos del CSG desde CSV (columnas: cve_code,name,active_ingredient,route_of_administration,presentation)"
  task import_medications: :environment do
    file_path = ENV["FILE"] || Rails.root.join("db", "seeds", "medications.csv")
    unless File.exist?(file_path)
      puts "ERROR: Archivo no encontrado: #{file_path}"
      puts "Uso: rake catalogs:import_medications FILE=/ruta/al/medications.csv"
      exit 1
    end

    require "csv"
    count = 0
    CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
      MedicationsCatalog.find_or_create_by(cve_code: row["cve_code"]) do |m|
        m.name                   = row["name"]
        m.active_ingredient      = row["active_ingredient"]
        m.route_of_administration = row["route_of_administration"]
        m.presentation           = row["presentation"]
      end
      count += 1
    end
    puts "Medicamentos: #{count} registros importados/actualizados."
  end

  desc "Importa el catálogo CLUES desde CSV (columnas: clues_code,name,state_code,municipality,institution_type,status)"
  task import_clues: :environment do
    file_path = ENV["FILE"] || Rails.root.join("db", "seeds", "clues.csv")
    unless File.exist?(file_path)
      puts "ERROR: Archivo no encontrado: #{file_path}"
      puts "Uso: rake catalogs:import_clues FILE=/ruta/al/clues.csv"
      exit 1
    end

    require "csv"
    count = 0
    CSV.foreach(file_path, headers: true, encoding: "UTF-8") do |row|
      CluesEstablishment.find_or_create_by(clues_code: row["clues_code"]) do |e|
        e.name             = row["name"]
        e.state_code       = row["state_code"]
        e.municipality     = row["municipality"]
        e.institution_type = row["institution_type"]
        e.status           = row["status"] || "active"
      end
      count += 1
    end
    puts "CLUES: #{count} establecimientos importados/actualizados."
  end
end
