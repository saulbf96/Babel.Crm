/**
 * Exportar a Excel (.xlsx) lo que el usuario está viendo (ya filtrado), con el estilo de UNO Contact.
 * La librería (exceljs) se descarga SOLO al exportar (import dinámico): no pesa en la carga inicial.
 * Regla: no se exportan IDs internos; se numera 1..N.
 */
export interface ColumnaExcel<T> {
  titulo: string;
  valor: (fila: T) => string | number | Date | null | undefined;
  ancho?: number;
  /** Formato de Excel, ej. 'dd/mm/yyyy'. */
  formato?: string;
  /** Texto largo: hace salto de línea dentro de la celda (ej. comentarios). */
  ajustar?: boolean;
}

export interface OpcionesExcel<T> {
  archivo: string; // sin extensión
  hoja: string;
  titulo: string;
  /** Línea informativa: filtro, búsqueda, quién y cuándo. */
  detalle: string;
  columnas: ColumnaExcel<T>[];
  filas: T[];
}

const AZUL = 'FF003087';
const MARINO = 'FF012169';
const GRIS = 'FF64748B';

export async function exportarExcel<T>(o: OpcionesExcel<T>): Promise<void> {
  const { Workbook } = await import('exceljs');
  const libro = new Workbook();
  libro.creator = 'UNO Contact';
  libro.created = new Date();

  const hoja = libro.addWorksheet(o.hoja.slice(0, 31), { views: [{ state: 'frozen', ySplit: 4 }] });
  const totalColumnas = o.columnas.length + 1; // + columna #

  // Título y detalle
  hoja.mergeCells(1, 1, 1, totalColumnas);
  const titulo = hoja.getCell(1, 1);
  titulo.value = o.titulo;
  titulo.font = { bold: true, size: 14, color: { argb: MARINO } };
  hoja.mergeCells(2, 1, 2, totalColumnas);
  const detalle = hoja.getCell(2, 1);
  detalle.value = o.detalle;
  detalle.font = { size: 10, color: { argb: GRIS } };

  // Encabezados (fila 4)
  const encabezados = ['#', ...o.columnas.map((c) => c.titulo)];
  const filaEnc = hoja.getRow(4);
  encabezados.forEach((t, i) => {
    const celda = filaEnc.getCell(i + 1);
    celda.value = t;
    celda.font = { bold: true, color: { argb: 'FFFFFFFF' } };
    celda.fill = { type: 'pattern', pattern: 'solid', fgColor: { argb: AZUL } };
    celda.alignment = { vertical: 'middle' };
  });
  filaEnc.height = 20;

  // Datos
  o.filas.forEach((fila, i) => {
    const r = hoja.getRow(5 + i);
    r.getCell(1).value = i + 1;
    o.columnas.forEach((c, j) => {
      const v = c.valor(fila);
      const celda = r.getCell(j + 2);
      celda.value = v instanceof Date ? horaLocal(v) : (v ?? '');
      if (c.formato) celda.numFmt = c.formato;
      celda.alignment = { vertical: 'top', wrapText: !!c.ajustar };
    });
  });

  // Anchos, filtros
  hoja.getColumn(1).width = 6;
  o.columnas.forEach((c, j) => (hoja.getColumn(j + 2).width = c.ancho ?? 18));
  hoja.autoFilter = { from: { row: 4, column: 1 }, to: { row: 4 + o.filas.length, column: totalColumnas } };

  const buffer = await libro.xlsx.writeBuffer();
  const blob = new Blob([buffer], { type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = `${o.archivo}.xlsx`;
  a.click();
  setTimeout(() => URL.revokeObjectURL(url), 1000);
}

/**
 * Excel no maneja zonas horarias y exceljs escribe las fechas en UTC: sin esto, 12:48 (hora de
 * México) saldría como 18:48. Se manda la MISMA hora del reloj local, marcada como UTC.
 */
function horaLocal(d: Date): Date {
  return new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate(), d.getHours(), d.getMinutes(), d.getSeconds()));
}

/** "2026-11-26" -> Date local (para que Excel lo trate como fecha). */
export function fechaExcel(iso: string | null | undefined): Date | null {
  if (!iso) return null;
  const [a, m, d] = iso.slice(0, 10).split('-').map(Number);
  return new Date(a, m - 1, d);
}

/** Marca de fecha-hora para nombres de archivo: 2026-11-26_1250 */
export function marcaArchivo(fecha = new Date()): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${fecha.getFullYear()}-${p(fecha.getMonth() + 1)}-${p(fecha.getDate())}_${p(fecha.getHours())}${p(fecha.getMinutes())}`;
}
