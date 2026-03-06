# Validador oficial de la CURP (Clave Única de Registro de Población)
# Cumple con el estándar RENAPO y la NOM-024-SSA3-2012.
#
# Verifica:
#   1. Formato morfológico (18 caracteres, regex oficial)
#   2. Dígito verificador mediante algoritmo Módulo 10
class CurpValidator < ActiveModel::EachValidator
  # Regex oficial RENAPO para validar morfología de la CURP.
  # Posiciones:
  #   1-4   : Letras iniciales (apellidos + nombre)
  #   5-10  : Fecha nacimiento AAMMDD
  #   11    : Sexo (H/M/X)
  #   12-13 : Clave entidad federativa INEGI
  #   14-16 : Consonantes internas
  #   17    : Siglo/homonimia (0-9 para nacidos ≤1999, A-Z para ≥2000)
  #   18    : Dígito verificador
  CURP_REGEX = /\A[A-Z]{4}\d{6}[HMX](AS|BC|BS|CC|CL|CM|CS|CH|DF|DG|GT|GR|HG|JC|MC|MN|MS|NT|NL|OC|PL|QT|QR|SP|SL|SR|TC|TS|TL|VZ|YN|ZS|NE)[B-DF-HJ-NP-TV-Z]{3}[0-9A-Z]\d\z/

  # Mapa de caracteres para el algoritmo de dígito verificador.
  # Conforme al estándar RENAPO oficial que incluye la Ñ entre N y O:
  # '0'..'9' → 0..9
  # 'A'..'N' → 10..23
  # 'Ñ'     → 24
  # 'O'..'Z' → 25..36
  CHAR_VALUES = (
    ('0'..'9').zip(0..9).to_a +
    ('A'..'N').zip(10..23).to_a +
    [['Ñ', 24]] +
    ('O'..'Z').zip(25..36).to_a
  ).to_h.freeze

  def validate_each(record, attribute, value)
    return if value.blank?

    curp = value.strip

    unless curp.match?(CURP_REGEX)
      record.errors.add(attribute, :invalid_curp_format,
        message: "no tiene el formato válido de CURP (18 caracteres según RENAPO)")
      return
    end

    unless valid_check_digit?(curp.upcase)
      record.errors.add(attribute, :invalid_curp_check_digit,
        message: "tiene un dígito verificador inválido (falla el algoritmo Módulo 10 de RENAPO)")
    end
  end

  private

  # Calcula y verifica el dígito verificador (posición 18) mediante Módulo 10.
  #
  # Algoritmo oficial RENAPO:
  #   1. Extraer los primeros 17 caracteres.
  #   2. Convertir cada carácter a su valor numérico (diccionario CHAR_VALUES).
  #   3. Multiplicar cada valor por su peso posicional: (19 - posición), posición 1..17.
  #   4. Sumar todos los productos.
  #   5. residuo = suma % 10
  #   6. verificador = (10 - residuo) % 10
  #   7. Comparar con el carácter en posición 18.
  def valid_check_digit?(curp)
    digits = curp[0..16].chars
    suma = digits.each_with_index.sum do |char, index|
      valor = CHAR_VALUES[char.upcase]
      peso  = 19 - (index + 1)   # posición 1-based → peso 18..2
      valor * peso
    end

    residuo     = suma % 10
    verificador = (10 - residuo) % 10

    # El carácter 18 siempre es un dígito numérico
    verificador == curp[17].to_i
  end
end
