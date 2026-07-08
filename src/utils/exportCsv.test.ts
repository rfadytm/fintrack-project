import { describe, expect, it } from "vitest";
import { toCsvString } from "./exportCsv";

describe("toCsvString", () => {
  it("builds a header row plus one row per record", () => {
    const csv = toCsvString([
      { Dokumen: "KK-0001", Jumlah: 30000 },
      { Dokumen: "KK-0002", Jumlah: 50000 },
    ]);
    expect(csv).toBe("Dokumen,Jumlah\nKK-0001,30000\nKK-0002,50000");
  });

  it("quotes cells containing commas, quotes, or newlines", () => {
    const csv = toCsvString([{ Keterangan: 'Beli "kopi", roti\nlagi' }]);
    expect(csv).toBe('Keterangan\n"Beli ""kopi"", roti\nlagi"');
  });

  it("leaves plain cells unquoted", () => {
    const csv = toCsvString([{ Kode: "5130", Nama: "Beban Makan" }]);
    expect(csv).toBe("Kode,Nama\n5130,Beban Makan");
  });
});
