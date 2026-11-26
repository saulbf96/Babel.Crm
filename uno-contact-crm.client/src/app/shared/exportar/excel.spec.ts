import { exportarExcel, fechaExcel } from './excel';

describe('Exportar a Excel', () => {
  it('genera un .xlsx con título, encabezados, numeración 1..N y sin IDs', async () => {
    let generado: Blob | undefined;
    let nombre = '';
    const crear = URL.createObjectURL;
    URL.createObjectURL = (b: Blob) => ((generado = b), 'blob:prueba');
    URL.revokeObjectURL = () => undefined;
    const clic = HTMLAnchorElement.prototype.click;
    HTMLAnchorElement.prototype.click = function (this: HTMLAnchorElement) { nombre = this.download; };

    await exportarExcel({
      archivo: 'empleados_activos_prueba',
      hoja: 'Empleados',
      titulo: 'Consulta de empleados · Activos',
      detalle: 'Filtro: Activos',
      filas: [
        { idEmpleado: 304, nombre: 'ANDREA BLANCO LABRA', ingreso: '2025-09-18', baja: new Date(2026, 10, 26, 12, 48) },
        { idEmpleado: 6, nombre: 'OMAR EMILIO RODRIGUEZ', ingreso: '2023-11-29' },
      ],
      columnas: [
        { titulo: 'Nombre', valor: (e) => e.nombre },
        { titulo: 'Ingreso', valor: (e) => fechaExcel(e.ingreso), formato: 'dd/mm/yyyy' },
        { titulo: 'Baja', valor: (e) => ('baja' in e ? e.baja : null), formato: 'dd/mm/yyyy hh:mm' },
      ],
    });
    URL.createObjectURL = crear;
    HTMLAnchorElement.prototype.click = clic;

    expect(nombre).toBe('empleados_activos_prueba.xlsx');
    const { Workbook } = await import('exceljs');
    const libro = new Workbook();
    await libro.xlsx.load(await generado!.arrayBuffer());
    const hoja = libro.getWorksheet('Empleados')!;
    expect(hoja.getCell('A1').value).toBe('Consulta de empleados · Activos');
    expect(hoja.getRow(4).values).toEqual([, '#', 'Nombre', 'Ingreso', 'Baja']);
    // La hora en Excel es la misma del reloj local (12:48), no la de UTC.
    const baja = hoja.getCell('D5').value as Date;
    expect(baja.getUTCHours()).toBe(12);
    expect(baja.getUTCMinutes()).toBe(48);
    expect(hoja.getCell('A5').value).toBe(1);
    expect(hoja.getCell('B5').value).toBe('ANDREA BLANCO LABRA');
    expect(hoja.getCell('A6').value).toBe(2);
    const todo = JSON.stringify(hoja.getSheetValues());
    expect(todo).not.toContain('304'); // no se exportan IDs internos
  });
});
