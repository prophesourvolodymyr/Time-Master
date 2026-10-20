use serde::Serialize;
use serde_json::ser::Formatter;
use std::io::{self, Write};

struct EvidenceFormatter;

impl Formatter for EvidenceFormatter {
    fn write_f64<W: ?Sized + Write>(&mut self, writer: &mut W, value: f64) -> io::Result<()> {
        if value == 0.0 {
            return writer.write_all(if value.is_sign_negative() {
                b"-0.0"
            } else {
                b"0.0"
            });
        }
        let mut buffer = ryu::Buffer::new();
        let encoded = buffer.format_finite(value);
        let number = if let Some(positive) = encoded.strip_prefix('-') {
            writer.write_all(b"-")?;
            positive
        } else {
            encoded
        };
        let (mantissa, exponent) = match number.split_once('e') {
            Some((mantissa, exponent)) => {
                (mantissa, exponent.parse::<i32>().map_err(io::Error::other)?)
            }
            None => (number, 0),
        };
        let mut digits = [0; 24];
        let mut count = 0;
        let mut decimal = mantissa.find('.').unwrap_or(mantissa.len()) as i32 + exponent;
        for digit in mantissa.bytes().filter(|b| *b != b'.') {
            if count == 0 && digit == b'0' {
                decimal -= 1;
            } else {
                digits[count] = digit;
                count += 1;
            }
        }
        while count > 1 && digits[count - 1] == b'0' {
            count -= 1;
        }
        if decimal <= -4 || decimal > 16 {
            writer.write_all(&digits[..1])?;
            if count > 1 {
                writer.write_all(b".")?;
                writer.write_all(&digits[1..count])?;
            }
            let exponent = decimal - 1;
            write!(
                writer,
                "e{}{:02}",
                if exponent < 0 { '-' } else { '+' },
                exponent.unsigned_abs()
            )
        } else if decimal <= 0 {
            writer.write_all(b"0.")?;
            for _ in 0..-decimal {
                writer.write_all(b"0")?;
            }
            writer.write_all(&digits[..count])
        } else if decimal as usize >= count {
            writer.write_all(&digits[..count])?;
            for _ in count..decimal as usize {
                writer.write_all(b"0")?;
            }
            writer.write_all(b".0")
        } else {
            let decimal = decimal as usize;
            writer.write_all(&digits[..decimal])?;
            writer.write_all(b".")?;
            writer.write_all(&digits[decimal..count])
        }
    }
}

pub(crate) fn evidence_json<T: ?Sized + Serialize>(value: &T) -> Result<String, serde_json::Error> {
    let mut bytes = Vec::new();
    let mut serializer = serde_json::Serializer::with_formatter(&mut bytes, EvidenceFormatter);
    value.serialize(&mut serializer)?;
    Ok(String::from_utf8(bytes).expect("JSON serialization is UTF-8"))
}
