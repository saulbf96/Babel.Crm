import { DatePipe } from '@angular/common';
import { HttpErrorResponse } from '@angular/common/http';
import { Component, inject, signal } from '@angular/core';
import { FormsModule } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatChipsModule } from '@angular/material/chips';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule } from '@angular/material/paginator';
import { PAGINADOR_EN_ESPANOL, Paginacion, TAMANOS_PAGINA } from '../../shared/paginacion/paginacion';
import { CargaAsignacion, ProcesoAsignacion } from '../../core/cargas/cargas.models';
import { CargasService } from '../../core/cargas/cargas.service';
import { Catalogos } from '../../core/catalogos/catalogos.models';
import { CatalogosService } from '../../core/catalogos/catalogos.service';
import { SesionService } from '../../core/sesion/sesion.service';

/** Máximo de filas que se guardan en staging (igual que ServicioCargas en el backend). */
const MAXIMO_FILAS = 5000;

/**
 * Carga de asignaciones (equivale a FRM_CARGAASIGNACIONES de BABEL ADMINISTRATIVO).
 * Por ahora registra la carga en staging: el proceso real del .exe está cifrado
 * y pendiente de confirmar con sistemas.
 */
@Component({
  selector: 'app-carga-asignaciones',
  imports: [
    DatePipe,
    FormsModule,
    MatButtonModule,
    MatChipsModule,
    MatFormFieldModule,
    MatIconModule,
    MatProgressBarModule,
    MatSelectModule,
    MatTableModule,
    MatPaginatorModule,
  ],
  providers: [PAGINADOR_EN_ESPANOL],
  templateUrl: './carga-asignaciones.html',
  styleUrl: './carga-asignaciones.css',
})
export class CargaAsignaciones {
  private readonly catalogosService = inject(CatalogosService);
  private readonly cargasService = inject(CargasService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(MatSnackBar);

  protected readonly catalogos = signal<Catalogos | null>(null);
  protected readonly procesos = signal<ProcesoAsignacion[]>([]);
  protected readonly cargas = signal<CargaAsignacion[]>([]);
  protected readonly pag = new Paginacion(this.cargas);
  protected readonly tamanos = TAMANOS_PAGINA;
  protected readonly carteraId = signal(0);
  protected readonly procesoId = signal(0);
  protected readonly nombreArchivo = signal('');
  protected readonly filas = signal<string[] | null>(null);
  protected readonly cargando = signal(true);
  protected readonly enviando = signal(false);

  protected readonly columnas = [
    'num',
    'cartera',
    'proceso',
    'archivo',
    'estatus',
    'registros',
    'errores',
    'usuario',
    'fecha',
  ];

  constructor() {
    void this.inicializar();
  }

  private async inicializar(): Promise<void> {
    this.cargando.set(true);
    try {
      const [catalogos, procesos] = await Promise.all([
        this.catalogosService.consultar(),
        this.cargasService.procesos(),
      ]);
      this.catalogos.set(catalogos);
      this.procesos.set(procesos);

      const actual = this.sesion.sesion()?.idCartera ?? catalogos.carteras[0]?.idCartera ?? 0;
      this.carteraId.set(actual);
      await this.cargarHistorial();
    } catch {
      this.avisos.open('No se pudieron cargar los catálogos de la carga.', 'Cerrar');
    } finally {
      this.cargando.set(false);
    }
  }

  protected async cambiarCartera(idCartera: number): Promise<void> {
    this.carteraId.set(idCartera);
    await this.cargarHistorial();
  }

  protected async cargarHistorial(): Promise<void> {
    try {
      const idCartera = this.carteraId() || undefined;
      this.cargas.set(await this.cargasService.consultar(idCartera));
    } catch {
      this.avisos.open('No se pudo cargar el historial de cargas.', 'Cerrar');
    }
  }

  protected async seleccionarArchivo(evento: Event): Promise<void> {
    const entrada = evento.target as HTMLInputElement;
    const archivo = entrada.files?.[0];
    if (!archivo) {
      this.limpiarArchivo();
      return;
    }

    this.nombreArchivo.set(archivo.name);
    this.filas.set(await this.leerFilas(archivo));
  }

  /**
   * Solo los archivos de texto se pueden leer en el navegador. Los Excel se
   * registran con su nombre: el proceso real los leerá en el servidor cuando
   * se habilite.
   */
  private async leerFilas(archivo: File): Promise<string[] | null> {
    const extension = archivo.name.split('.').pop()?.toLowerCase() ?? '';
    if (extension !== 'csv' && extension !== 'txt') return null;

    const texto = await archivo.text();
    return texto
      .split(/\r?\n/)
      .map((fila) => fila.trim())
      .filter((fila) => fila.length > 0)
      .slice(0, MAXIMO_FILAS);
  }

  protected limpiarArchivo(): void {
    this.nombreArchivo.set('');
    this.filas.set(null);
  }

  protected async registrar(): Promise<void> {
    if (this.enviando()) return;

    if (!this.carteraId()) {
      this.avisos.open('Selecciona una cartera.', 'Cerrar');
      return;
    }
    if (!this.procesoId()) {
      this.avisos.open('Selecciona el tipo de proceso.', 'Cerrar');
      return;
    }
    if (!this.nombreArchivo()) {
      this.avisos.open('Selecciona el archivo a cargar.', 'Cerrar');
      return;
    }

    this.enviando.set(true);
    try {
      const resultado = await this.cargasService.crear({
        idCartera: this.carteraId(),
        proceso: this.procesoId(),
        nombreArchivo: this.nombreArchivo(),
        filas: this.filas(),
      });
      this.avisos.open(
        `${resultado.mensaje} Carga #${resultado.idCarga} con ${resultado.filas} fila(s).`,
        'Cerrar',
        { duration: 6000 },
      );
      this.procesoId.set(0);
      this.limpiarArchivo();
      await this.cargarHistorial();
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.enviando.set(false);
    }
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse) {
      return e.error?.title ?? 'No se pudo registrar la carga.';
    }
    return 'No hay comunicación con el servidor.';
  }
}
