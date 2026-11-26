import { HttpErrorResponse } from '@angular/common/http';
import { Component, DestroyRef, TemplateRef, computed, inject, signal, viewChild } from '@angular/core';
import { MatDialog, MatDialogModule, MatDialogRef } from '@angular/material/dialog';
import { MatPaginatorModule } from '@angular/material/paginator';
import { MatTooltipModule } from '@angular/material/tooltip';
import { MatButtonToggleModule } from '@angular/material/button-toggle';
import { PAGINADOR_EN_ESPANOL, Paginacion, TAMANOS_PAGINA } from '../../shared/paginacion/paginacion';
import { FormsModule, NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatChipsModule } from '@angular/material/chips';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { AvisosService } from '../../shared/avisos/avisos.service';
import { PermisosEditor } from '../../shared/permisos-editor/permisos-editor';
import { OpcionPermiso, PermisosEmpleado, PermisosService } from '../../core/permisos/permisos.service';
import { exportarExcel, fechaExcel, marcaArchivo } from '../../shared/exportar/excel';
import { MatTableModule } from '@angular/material/table';
import { Catalogos } from '../../core/catalogos/catalogos.models';
import { CatalogosService } from '../../core/catalogos/catalogos.service';
import { EmpleadosService } from '../../core/empleados/empleados.service';
import { EmpleadoResumen } from '../../core/empleados/empleados.models';
import { aServidor, evaluarHorario } from '../../core/empleados/horario';
import { SesionService } from '../../core/sesion/sesion.service';
import { EJEMPLOS_NOMBRE, normalizarNombre, soloLetras } from '../../core/empleados/nombre';

/** Minúsculas y sin acentos, para buscar sin importar cómo se escriba. */
function normalizar(texto: string): string {
  return (texto ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase().trim();
}

/** Todo lo que se puede buscar de un empleado, ya normalizado (se calcula una vez por renglón). */
const cacheBuscable = new WeakMap<EmpleadoResumen, string>();
function textoBuscable(e: EmpleadoResumen): string {
  let t = cacheBuscable.get(e);
  if (t === undefined) {
    t = normalizar([e.nombreCompleto, e.usuario, e.puesto, e.departamento, e.cartera].filter(Boolean).join(' '));
    cacheBuscable.set(e, t);
  }
  return t;
}

/**
 * Pantalla "Consulta Empleados" (equivale a FRM_CONSULTAEMPLEADOS de BABEL ADMINISTRATIVO)
 * + Editar empleado (NUEVO: BABEL nunca tuvo edición): nombre, puesto, sexo y horario de acceso.
 */
@Component({
  selector: 'app-empleados',
  imports: [
    FormsModule,
    ReactiveFormsModule,
    MatButtonModule,
    MatCheckboxModule,
    MatChipsModule,
    MatDialogModule,
    MatPaginatorModule,
    MatTooltipModule,
    PermisosEditor,
    MatButtonToggleModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatSelectModule,
    MatTableModule,
  ],
  providers: [PAGINADOR_EN_ESPANOL],
  templateUrl: './empleados.html',
  styleUrl: './empleados.css',
})
export class Empleados {
  private readonly servicio = inject(EmpleadosService);
  private readonly catalogosService = inject(CatalogosService);
  private readonly sesion = inject(SesionService);
  private readonly avisos = inject(AvisosService);

  /** Búsqueda en tiempo real (se filtra en el navegador mientras se escribe). */
  protected readonly texto = signal('');
  /** Activos (por defecto), solo los dados de baja, o todos. */
  protected readonly estatus = signal<'activos' | 'inactivos' | 'todos'>('activos');
  /** Todos los empleados (activos e inactivos) se cargan una vez; los filtros son locales. */
  protected readonly todos = signal<EmpleadoResumen[]>([]);
  protected readonly cargando = signal(false);
  protected readonly busco = signal(false);

  protected readonly filtrados = computed(() => {
    const palabras = normalizar(this.texto()).split(/\s+/).filter(Boolean);
    const estatus = this.estatus();
    return this.todos().filter(
      (e) =>
        (estatus === 'todos' || (estatus === 'activos' ? e.activo : !e.activo)) &&
        // todas las palabras deben aparecer en algún dato (ej. "aztec supervisor")
        palabras.every((p) => textoBuscable(e).includes(p)),
    );
  });

  protected readonly pag = new Paginacion(this.filtrados);
  protected readonly tamanos = TAMANOS_PAGINA;

  private readonly dialogo = inject(MatDialog);
  private readonly plantillaEditar = viewChild.required<TemplateRef<unknown>>('dlgEditar');
  private ventana?: MatDialogRef<unknown>;

  protected readonly columnas = ['num', 'usuario', 'nombreCompleto', 'puesto', 'departamento', 'cartera', 'turno', 'fechaIngreso', 'activo', 'acciones'];

  // ---------- Exportar a Excel (exactamente lo que se ve: estatus + búsqueda) ----------
  protected readonly exportando = signal(false);

  protected async exportar(): Promise<void> {
    if (this.exportando()) return;
    this.exportando.set(true);
    try {
      const etiquetas = { activos: 'Activos', inactivos: 'Inactivos', todos: 'Todos' } as const;
      const estatus = etiquetas[this.estatus()];
      const busqueda = this.texto().trim();
      const ahora = new Date();
      await exportarExcel({
        archivo: `empleados_${estatus.toLowerCase()}_${marcaArchivo(ahora)}`,
        hoja: 'Empleados',
        titulo: `Consulta de empleados · ${estatus}`,
        detalle:
          `Filtro: ${estatus}` +
          (busqueda ? ` · Búsqueda: "${busqueda}"` : '') +
          ` · ${this.filtrados().length} empleado(s) · Generado por ${this.sesion.usuario()} el ` +
          ahora.toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' }),
        filas: this.filtrados(),
        columnas: [
          { titulo: 'Usuario', valor: (e) => e.usuario ?? '', ancho: 14 },
          { titulo: 'Nombre', valor: (e) => e.nombreCompleto, ancho: 36 },
          { titulo: 'Puesto', valor: (e) => e.puesto, ancho: 26 },
          { titulo: 'Departamento', valor: (e) => e.departamento, ancho: 22 },
          { titulo: 'Cartera', valor: (e) => e.cartera ?? '', ancho: 24 },
          { titulo: 'Horario', valor: (e) => this.horarioDe(e), ancho: 22 },
          { titulo: 'Ingreso', valor: (e) => fechaExcel(e.fechaIngreso), ancho: 12, formato: 'dd/mm/yyyy' },
          { titulo: 'Estatus', valor: (e) => (e.activo ? 'Activo' : 'Inactivo'), ancho: 10 },
        ],
      });
    } catch {
      this.avisos.error('No se pudo generar el archivo de Excel.');
    } finally {
      this.exportando.set(false);
    }
  }

  // ---------- Permisos en Editar ----------
  private readonly permisosService = inject(PermisosService);
  protected readonly opcionesPermiso = signal<OpcionPermiso[]>([]);
  protected readonly permisosEdicion = signal<PermisosEmpleado | null>(null);
  protected readonly permisos = signal<string[]>([]);
  protected readonly permisosQuePuedoDar = this.sesion.permisosQuePuedeDar();

  // ---------- Edición ----------
  protected readonly ejemplos = EJEMPLOS_NOMBRE;
  protected readonly catalogos = signal<Catalogos | null>(null);
  protected readonly editando = signal<EmpleadoResumen | null>(null);
  protected readonly guardando = signal(false);
  protected readonly errorEdicion = signal<string | null>(null);
  private readonly idCarteraSesion = computed(() => this.sesion.sesion()?.idCartera ?? 0);

  protected readonly formulario = inject(NonNullableFormBuilder).group({
    nombre: ['', [Validators.required, Validators.maxLength(100), soloLetras]],
    paterno: ['', [Validators.required, Validators.maxLength(100), soloLetras]],
    materno: ['', [Validators.required, Validators.maxLength(100), soloLetras]],
    idPuesto: [0, [Validators.min(1)]],
    idSexo: [0, [Validators.min(1)]],
    horaEntrada: [''],
    horaSalida: [''],
    noAplicaHorario: [false],
  });

  private readonly horario = signal({ entrada: '', salida: '', noAplica: false });
  protected readonly estadoHorario = computed(() =>
    evaluarHorario(this.horario().entrada, this.horario().salida, this.horario().noAplica),
  );


  /**
   * "Sin restricción de horario": las horas se vacían y se bloquean (no se pueden capturar).
   * Al desmarcarlo se desbloquean y regresan las que tenía (o el horario por defecto).
   */
  private horasPrevias = { entrada: '', salida: '' };
  private alternarHoras(sinRestriccion: boolean): void {
    const { horaEntrada: he, horaSalida: hs } = this.formulario.controls;
    if (sinRestriccion) {
      if (he.value || hs.value) this.horasPrevias = { entrada: he.value, salida: hs.value };
      he.setValue('', { emitEvent: false });
      hs.setValue('', { emitEvent: false });
      he.disable({ emitEvent: false });
      hs.disable({ emitEvent: false });
    } else if (he.disabled) {
      he.enable({ emitEvent: false });
      hs.enable({ emitEvent: false });
      he.setValue(this.horasPrevias.entrada || '', { emitEvent: false });
      hs.setValue(this.horasPrevias.salida || '', { emitEvent: false });
    }
    this.horario.set({ entrada: he.value, salida: hs.value, noAplica: sinRestriccion });
  }

  constructor() {
    void this.cargar();
    this.formulario.controls.noAplicaHorario.valueChanges.subscribe((sin) => this.alternarHoras(!!sin));
    // La lista se filtra en el navegador; al regresar a la pestaña se recarga para ver
    // cambios hechos en otra pantalla o pestaña (altas, bajas, reactivaciones).
    const alVolver = () => {
      if (document.visibilityState === 'visible' && !this.cargando() && !this.editando()) void this.cargar(true);
    };
    document.addEventListener('visibilitychange', alVolver);
    inject(DestroyRef).onDestroy(() => document.removeEventListener('visibilitychange', alVolver));
    this.formulario.valueChanges.subscribe((v) =>
      this.horario.set({ entrada: v.horaEntrada ?? '', salida: v.horaSalida ?? '', noAplica: !!v.noAplicaHorario }),
    );
  }

  /** @param silencioso true = recarga en segundo plano sin barra de progreso ni regresar a la página 1. */
  protected async cargar(silencioso = false): Promise<void> {
    if (!silencioso) this.cargando.set(true);
    const pagina = this.pag.indice();
    try {
      this.todos.set(await this.servicio.consultar({ soloActivos: false }));
      if (silencioso) this.pag.indice.set(pagina);
    } finally {
      this.cargando.set(false);
      this.busco.set(true);
    }
  }

  protected filtrar(valor: string): void {
    this.texto.set(valor ?? '');
    this.pag.reiniciar();
  }

  protected cambiarEstatus(valor: 'activos' | 'inactivos' | 'todos'): void {
    this.estatus.set(valor);
    this.pag.reiniciar();
    void this.cargar(true); // trae lo más reciente (ej. bajas hechas en otra pantalla)
  }

  /** Por qué no se puede editar (se ve al pasar el mouse sobre el botón deshabilitado). */
  protected motivoNoEditar(e: EmpleadoResumen): string {
    if (!e.activo) return 'Está dado de baja. Para cambiar sus datos, reactívalo en Bajas de personal.';
    return `Pertenece a la cartera ${e.cartera ?? '(sin cartera)'}. Para editarlo, cámbiate a esa cartera en "Cambia cartera".`;
  }

  /** Solo se editan empleados activos de la cartera de la sesión (el servidor lo vuelve a validar). */
  protected puedeEditar(e: EmpleadoResumen): boolean {
    return e.activo && e.idCartera === this.idCarteraSesion();
  }

  /** Texto de la columna Horario. */
  protected horarioDe(e: EmpleadoResumen): string {
    const horas = e.horaEntrada && e.horaSalida ? `${e.horaEntrada.slice(0, 5)} – ${e.horaSalida.slice(0, 5)}` : '';
    // Sin restricción: puede entrar a cualquier hora (las horas capturadas no se aplican).
    if (!e.aplicaHorario) return 'Sin restricción';
    return horas || e.turno || '—';
  }

  protected async editar(e: EmpleadoResumen): Promise<void> {
    if (!this.catalogos()) {
      try {
        this.catalogos.set(await this.catalogosService.consultar());
      } catch {
        this.avisos.error('No se pudieron cargar los catálogos.');
        return;
      }
    }
    this.errorEdicion.set(null);
    this.horasPrevias = { entrada: e.horaEntrada?.slice(0, 5) ?? '', salida: e.horaSalida?.slice(0, 5) ?? '' };
    this.formulario.controls.horaEntrada.enable({ emitEvent: false });
    this.formulario.controls.horaSalida.enable({ emitEvent: false });
    this.formulario.reset({
      nombre: e.nombre,
      paterno: e.paterno,
      materno: e.materno ?? '',
      idPuesto: e.idPuesto,
      idSexo: e.idSexo,
      horaEntrada: e.horaEntrada?.slice(0, 5) ?? '',
      horaSalida: e.horaSalida?.slice(0, 5) ?? '',
      noAplicaHorario: !e.aplicaHorario && !!e.horaEntrada,
    });
    this.alternarHoras(this.formulario.controls.noAplicaHorario.value);
    this.editando.set(e);
    // Permisos actuales (si quien edita es administrador; si es él mismo, se ven bloqueados).
    this.permisosEdicion.set(null);
    if (this.sesion.puedeAdministrarPermisos()) {
      void Promise.all([this.permisosService.catalogo(), this.permisosService.deEmpleado(e.idEmpleado)])
        .then(([opciones, actuales]) => {
          this.opcionesPermiso.set(opciones);
          this.permisosEdicion.set(actuales);
          this.permisos.set(actuales.permisos);
        })
        .catch(() => undefined);
    }
    // Ventana al centro de la pantalla: no importa en qué renglón esté.
    this.ventana = this.dialogo.open(this.plantillaEditar(), {
      width: '760px',
      maxWidth: '95vw',
      maxHeight: '90vh',
      disableClose: true, // no se cierra por un clic afuera y se pierdan los cambios
      autoFocus: 'first-tabbable',
    });
    this.ventana.afterClosed().subscribe(() => {
      this.editando.set(null);
      this.errorEdicion.set(null);
    });
  }

  /** ¿Cambió algo en Permisos? Solo entonces se mandan (y solo si los puede editar). */
  private permisosCambiados(): boolean {
    const pe = this.permisosEdicion();
    if (!pe?.puedeEditar) return false;
    const antes = new Set(pe.permisos);
    const ahora = new Set(this.permisos());
    return antes.size !== ahora.size || [...ahora].some((p) => !antes.has(p));
  }

  protected cancelarEdicion(): void {
    this.ventana?.close();
  }

  protected async guardarEdicion(): Promise<void> {
    const e = this.editando();
    if (!e || this.guardando()) return;
    if (this.formulario.invalid || !this.estadoHorario().valido) {
      this.formulario.markAllAsTouched();
      return;
    }
    const v = this.formulario.getRawValue();
    this.guardando.set(true);
    this.errorEdicion.set(null);
    try {
      await this.servicio.editar(e.idEmpleado, {
        nombre: normalizarNombre(v.nombre),
        paterno: normalizarNombre(v.paterno),
        materno: normalizarNombre(v.materno),
        idPuesto: v.idPuesto,
        idSexo: v.idSexo,
        horaEntrada: aServidor(v.horaEntrada),
        horaSalida: aServidor(v.horaSalida),
        aplicaHorario: this.estadoHorario().aplica,
        permisos: this.permisosCambiados() ? this.permisos() : undefined,
      });
      const nombreCompleto = [v.nombre, v.paterno, v.materno].map((x) => x.trim()).filter(Boolean).join(' ');
      // La nota del horario solo si cambió (el horario se revisa al iniciar sesión).
      const cambioHorario =
        (e.horaEntrada?.slice(0, 5) ?? '') !== v.horaEntrada ||
        (e.horaSalida?.slice(0, 5) ?? '') !== v.horaSalida ||
        e.aplicaHorario !== this.estadoHorario().aplica;
      this.avisos.exito(
        cambioHorario
          ? `Cambios guardados: ${nombreCompleto}. El nuevo horario aplica desde su próximo inicio de sesión.`
          : `Cambios guardados: ${nombreCompleto}.`,
        cambioHorario ? 5000 : 3500,
      );
      this.ventana?.close();
      // Refresca sin regresar a la página 1: el admin sigue donde estaba.
      const pagina = this.pag.indice();
      await this.cargar();
      this.pag.indice.set(pagina);
    } catch (err) {
      this.errorEdicion.set(
        err instanceof HttpErrorResponse && err.status === 400 && err.error?.title
          ? err.error.title
          : 'No se pudieron guardar los cambios. Intenta de nuevo.',
      );
    } finally {
      this.guardando.set(false);
    }
  }
}
