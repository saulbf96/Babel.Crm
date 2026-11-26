import { HttpErrorResponse } from '@angular/common/http';
import { Component, computed, inject, signal } from '@angular/core';
import { NonNullableFormBuilder, ReactiveFormsModule, Validators } from '@angular/forms';
import { MatButtonModule } from '@angular/material/button';
import { MatFormFieldModule } from '@angular/material/form-field';
import { MatIconModule } from '@angular/material/icon';
import { MatInputModule } from '@angular/material/input';
import { MatProgressBarModule } from '@angular/material/progress-bar';
import { MatSelectModule } from '@angular/material/select';
import { MatSnackBar } from '@angular/material/snack-bar';
import { DatePipe } from '@angular/common';
import { RouterLink } from '@angular/router';
import { CarterasService } from '../../core/carteras/carteras.service';
import { Cartera } from '../../core/catalogos/catalogos.models';
import { Catalogos } from '../../core/catalogos/catalogos.models';
import { CatalogosService } from '../../core/catalogos/catalogos.service';
import { EmpleadoCoincidente } from '../../core/empleados/empleados.models';
import { EmpleadosService } from '../../core/empleados/empleados.service';
import {
  HORA_ENTRADA_DEFECTO,
  HORA_SALIDA_DEFECTO,
  aServidor,
  evaluarHorario,
} from '../../core/empleados/horario';
import { SesionService } from '../../core/sesion/sesion.service';
import { AvisosService } from '../../shared/avisos/avisos.service';
import { CredencialesDialogo } from '../../shared/credenciales/credenciales-dialogo';
import { MatDialog } from '@angular/material/dialog';
import { PermisosEditor } from '../../shared/permisos-editor/permisos-editor';
import { OpcionPermiso, PermisosService } from '../../core/permisos/permisos.service';
import { EJEMPLOS_NOMBRE, normalizarNombre, soloLetras } from '../../core/empleados/nombre';
import { MatCheckboxModule } from '@angular/material/checkbox';
import { MatTableModule } from '@angular/material/table';
import { MatPaginatorModule } from '@angular/material/paginator';
import { MatTooltipModule } from '@angular/material/tooltip';
import { AltaRegistrada } from '../../core/empleados/empleados.models';
import { PAGINADOR_EN_ESPANOL, Paginacion, TAMANOS_PAGINA } from '../../shared/paginacion/paginacion';
import { exportarExcel, marcaArchivo } from '../../shared/exportar/excel';

/** yyyy-MM-dd local. */
function fechaIso(d: Date): string {
  const p = (n: number) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())}`;
}

/** Lunes de la semana de la fecha (yyyy-MM-dd). */
function lunesDe(d: Date): string {
  const l = new Date(d);
  l.setDate(d.getDate() - ((d.getDay() + 6) % 7));
  return fechaIso(l);
}

/** yyyy-MM-dd -> dd/MM/yyyy */
function aTexto(iso: string): string {
  const [a, m, d] = iso.split('-');
  return `${d}/${m}/${a}`;
}

/** Alta de empleados (equivale a FRM_ALTAEMPLEADOS de BABEL ADMINISTRATIVO). */
@Component({
  selector: 'app-alta-empleados',
  imports: [
    DatePipe,
    RouterLink,
    ReactiveFormsModule,
    MatButtonModule,
    MatCheckboxModule,
    PermisosEditor,
    MatTableModule,
    MatPaginatorModule,
    MatTooltipModule,
    MatFormFieldModule,
    MatIconModule,
    MatInputModule,
    MatProgressBarModule,
    MatSelectModule,
  ],
  providers: [PAGINADOR_EN_ESPANOL],
  templateUrl: './alta-empleados.html',
  styleUrl: './alta-empleados.css',
})
export class AltaEmpleados {
  private readonly catalogosService = inject(CatalogosService);
  private readonly empleadosService = inject(EmpleadosService);
  private readonly sesion = inject(SesionService);
  private readonly carterasService = inject(CarterasService);
  private readonly avisos = inject(MatSnackBar);
  private readonly avisosMarca = inject(AvisosService);
  private readonly dialogo = inject(MatDialog);

  protected readonly ejemplos = EJEMPLOS_NOMBRE;

  /** Personas que ya existen con el mismo nombre: si hay, NO se dio de alta. */
  protected readonly coincidencias = signal<EmpleadoCoincidente[]>([]);

  protected readonly catalogos = signal<Catalogos | null>(null);
  protected readonly cargando = signal(true);
  protected readonly enviando = signal(false);

  /** Cartera activa de la sesión: el alta siempre se registra en ella, como el .exe. */
  protected readonly carteraActual = this.sesion.cartera;

  protected readonly formulario = inject(NonNullableFormBuilder).group({
    // Multi-campaña: empieza vacío; el admin elige una o varias.
    carteras: [[] as number[], [Validators.required]],
    carteraPrincipal: [0],
    idPuesto: [0, [Validators.min(1)]],
    idSexo: [0, [Validators.min(1)]],
    // Horario por defecto (como la contraseña temporal): 08:00 a 14:30; el admin lo ajusta si hace falta.
    // Vacías las dos = no aplica horario.
    horaEntrada: [HORA_ENTRADA_DEFECTO],
    horaSalida: [HORA_SALIDA_DEFECTO],
    noAplicaHorario: [false],
    nombre: ['', [Validators.required, Validators.maxLength(100), soloLetras]],
    paterno: ['', [Validators.required, Validators.maxLength(100), soloLetras]],
    materno: ['', [Validators.required, Validators.maxLength(100), soloLetras]],
  });

  /** Horario capturado, para mostrar la jornada y si es válida en vivo. */
  private readonly horario = signal({ entrada: HORA_ENTRADA_DEFECTO, salida: HORA_SALIDA_DEFECTO, noAplica: false });
  protected readonly estadoHorario = computed(() =>
    evaluarHorario(this.horario().entrada, this.horario().salida, this.horario().noAplica),
  );

  // ---------- Historial de altas ----------
  protected readonly hoy = fechaIso(new Date());
  protected readonly desde = signal(lunesDe(new Date()));
  protected readonly hasta = signal(this.hoy);
  protected readonly altas = signal<AltaRegistrada[]>([]);
  protected readonly cargandoAltas = signal(false);
  protected readonly errorRango = signal<string | null>(null);
  protected readonly exportando = signal(false);
  protected readonly pagAltas = new Paginacion(this.altas);
  protected readonly tamanos = TAMANOS_PAGINA;
  protected readonly columnasAltas = ['num', 'fecha', 'nombre', 'usuario', 'puesto', 'horario', 'registro', 'estatus'];
  protected readonly esSemanaActual = computed(() => this.desde() === lunesDe(new Date()) && this.hasta() === this.hoy);
  protected readonly textoRango = computed(() =>
    this.esSemanaActual() ? 'Esta semana' : `Del ${aTexto(this.desde())} al ${aTexto(this.hasta())}`,
  );

  protected async cargarAltas(): Promise<void> {
    this.errorRango.set(null);
    if (!this.desde() || !this.hasta()) return;
    if (this.desde() > this.hoy || this.hasta() > this.hoy) {
      this.errorRango.set('No se pueden consultar fechas futuras: usa hoy o días anteriores.');
      this.altas.set([]);
      return;
    }
    if (this.desde() > this.hasta()) {
      this.errorRango.set('"Desde" no puede ser mayor que "Hasta".');
      this.altas.set([]);
      return;
    }
    this.cargandoAltas.set(true);
    try {
      this.altas.set(await this.empleadosService.altas(this.desde(), this.hasta()));
      this.pagAltas.reiniciar();
    } catch (e) {
      this.altas.set([]);
      this.errorRango.set(this.mensajeDeError(e));
    } finally {
      this.cargandoAltas.set(false);
    }
  }

  protected cambiarDesde(valor: string): void {
    this.desde.set(valor);
    void this.cargarAltas();
  }

  protected cambiarHasta(valor: string): void {
    this.hasta.set(valor);
    void this.cargarAltas();
  }

  protected semanaActual(): void {
    this.desde.set(lunesDe(new Date()));
    this.hasta.set(this.hoy);
    void this.cargarAltas();
  }

  protected horarioAlta(a: AltaRegistrada): string {
    if (!a.aplicaHorario) return 'Sin restricción';
    return a.horaEntrada && a.horaSalida ? `${a.horaEntrada.slice(0, 5)} – ${a.horaSalida.slice(0, 5)}` : '—';
  }

  protected async exportarAltas(): Promise<void> {
    if (this.exportando()) return;
    this.exportando.set(true);
    try {
      const ahora = new Date();
      await exportarExcel({
        archivo: `altas_${this.desde()}_a_${this.hasta()}_${marcaArchivo(ahora)}`,
        hoja: 'Altas',
        titulo: `Altas de empleados · ${this.carteraActual()}`,
        detalle:
          `Del ${aTexto(this.desde())} al ${aTexto(this.hasta())} · ${this.altas().length} alta(s) · Generado por ` +
          `${this.sesion.usuario()} el ${ahora.toLocaleString('es-MX', { dateStyle: 'short', timeStyle: 'short' })}`,
        filas: this.altas(),
        columnas: [
          { titulo: 'Fecha de alta', valor: (a) => new Date(a.fechaAlta), ancho: 18, formato: 'dd/mm/yyyy hh:mm' },
          { titulo: 'Empleado', valor: (a) => a.nombreCompleto, ancho: 36 },
          { titulo: 'Usuario', valor: (a) => a.usuario ?? 'Pendiente', ancho: 14 },
          { titulo: 'Puesto', valor: (a) => a.puesto, ancho: 26 },
          { titulo: 'Horario', valor: (a) => this.horarioAlta(a), ancho: 18 },
          { titulo: 'Registró', valor: (a) => a.registradoPor, ancho: 14 },
          { titulo: 'Estatus', valor: (a) => (a.activo ? 'Activo' : 'Inactivo'), ancho: 10 },
        ],
      });
    } catch {
      this.avisos.open('No se pudo generar el archivo de Excel.', undefined, { duration: 5000 });
    } finally {
      this.exportando.set(false);
    }
  }

  // ---------- Permisos (solo administradores / ROOT) ----------
  private readonly permisosService = inject(PermisosService);
  protected readonly puedeDarPermisos = this.sesion.puedeAdministrarPermisos();
  protected readonly esRoot = this.sesion.esRoot();
  protected readonly permisosQuePuedoDar = this.sesion.permisosQuePuedeDar();
  protected readonly opcionesPermiso = signal<OpcionPermiso[]>([]);
  protected readonly permisos = signal<string[]>([]);

  /** Al elegir el puesto, las casillas se marcan con lo que le toca. */
  private async permisosDelPuesto(idPuesto: number): Promise<void> {
    if (!this.puedeDarPermisos || !idPuesto) {
      this.permisos.set([]);
      return;
    }
    try {
      this.permisos.set(await this.permisosService.delPuesto(idPuesto));
    } catch {
      this.permisos.set([]);
    }
  }


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
      he.setValue(this.horasPrevias.entrada || HORA_ENTRADA_DEFECTO, { emitEvent: false });
      hs.setValue(this.horasPrevias.salida || HORA_SALIDA_DEFECTO, { emitEvent: false });
    }
    this.horario.set({ entrada: he.value, salida: hs.value, noAplica: sinRestriccion });
  }

  // ---------- Campañas (multi-campaña) ----------
  protected readonly carterasDisponibles = signal<Cartera[]>([]);
  private readonly carterasSel = signal<number[]>([]);
  protected readonly carterasElegidas = computed(() =>
    this.carterasDisponibles().filter((c) => this.carterasSel().includes(c.idCartera)),
  );
  protected readonly resumenCampanas = computed(() => {
    const e = this.carterasElegidas();
    return e.length <= 2 ? e.map((c) => c.nombre).join(', ') : `${e[0].nombre} y ${e.length - 1} más`;
  });

  /** Las campañas empiezan vacías: el admin elige (no se toma la de su sesión). */
  private campanaPorDefecto(): void {
    this.formulario.controls.carteras.setValue([]);
    this.formulario.controls.carteras.markAsUntouched();
    this.formulario.controls.carteraPrincipal.setValue(0);
  }

  constructor() {
    void this.cargar();
    void this.cargarAltas();
    void this.carterasService
      .consultar()
      .then((c) => this.carterasDisponibles.set(c))
      .catch(() => undefined);
    this.campanaPorDefecto();
    this.carterasSel.set(this.formulario.controls.carteras.value);
    // La principal siempre es una de las elegidas.
    this.formulario.controls.carteras.valueChanges.subscribe((ids) => {
      this.carterasSel.set(ids ?? []);
      const principal = this.formulario.controls.carteraPrincipal;
      if (!ids?.includes(principal.value)) principal.setValue(ids?.[0] ?? 0);
    });
    this.formulario.controls.noAplicaHorario.valueChanges.subscribe((sin) => this.alternarHoras(!!sin));
    if (this.puedeDarPermisos) {
      void this.permisosService.catalogo().then((o) => this.opcionesPermiso.set(o)).catch(() => undefined);
    }
    this.formulario.controls.idPuesto.valueChanges.subscribe((id) => void this.permisosDelPuesto(id));
    this.formulario.valueChanges.subscribe((v) =>
      this.horario.set({ entrada: v.horaEntrada ?? '', salida: v.horaSalida ?? '', noAplica: !!v.noAplicaHorario }),
    );
  }

  private async cargar(): Promise<void> {
    this.cargando.set(true);
    try {
      this.catalogos.set(await this.catalogosService.consultar());
    } catch {
      this.avisos.open('No se pudieron cargar los catálogos.', 'Cerrar');
    } finally {
      this.cargando.set(false);
    }
  }

  /** @param confirmarHomonimo true cuando el admin ya revisó las coincidencias y es otra persona. */
  protected async guardar(confirmarHomonimo = false): Promise<void> {
    if (this.formulario.invalid || !this.estadoHorario().valido || this.enviando()) {
      this.formulario.markAllAsTouched();
      return;
    }

    this.enviando.set(true);
    try {
      const valores = this.formulario.getRawValue();
      const resultado = await this.empleadosService.alta({
        idPuesto: valores.idPuesto,
        idSexo: valores.idSexo,
        horaEntrada: aServidor(valores.horaEntrada),
        horaSalida: aServidor(valores.horaSalida),
        aplicaHorario: this.estadoHorario().aplica,
        permisos: this.puedeDarPermisos && valores.idPuesto ? this.permisos() : undefined,
        carteras: valores.carteras,
        carteraPrincipal: valores.carteraPrincipal || null,
        nombre: normalizarNombre(valores.nombre),
        paterno: normalizarNombre(valores.paterno),
        materno: normalizarNombre(valores.materno),
        confirmarHomonimo,
      });
      if (resultado.coincidencias?.length) {
        // La persona ya existe: no se dio de alta. Se muestran las opciones.
        this.coincidencias.set(resultado.coincidencias);
        return;
      }
      const nombre = [valores.nombre, valores.paterno, valores.materno].map(normalizarNombre).join(' ');
      if (resultado.usuario && resultado.contrasenaTemporal) {
        // Usuario y contraseña temporal ÚNICA: la ventana no se cierra sola (tiempo para copiarlos).
        this.dialogo.open(CredencialesDialogo, {
          data: { titulo: 'Empleado dado de alta', nombre, usuario: resultado.usuario, contrasena: resultado.contrasenaTemporal },
          width: '520px',
          maxWidth: '95vw',
          disableClose: true,
          autoFocus: false,
        });
      } else {
        this.avisosMarca.exito(`${nombre} quedó dado de alta.`, 5000, 'Empleado dado de alta');
      }
      this.limpiar();
      void this.cargarAltas(); // la nueva alta aparece en el historial
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.enviando.set(false);
    }
  }

  /** Lo mueve a la cartera activa (igual que "Asignar personal"): deja su cartera anterior. */
  protected async moverAEstaCartera(c: EmpleadoCoincidente): Promise<void> {
    const idCartera = this.sesion.sesion()?.idCartera;
    if (!idCartera) return;
    await this.accion(
      () => this.carterasService.asignar(idCartera, [c.idEmpleado], null, false),
      `${c.nombreCompleto} ahora está en ${this.carteraActual()}.`,
    );
  }

  /** Le da acceso también a la cartera activa, sin quitarle la suya. */
  protected async darAcceso(c: EmpleadoCoincidente): Promise<void> {
    await this.accion(
      () => this.empleadosService.darAccesoCartera(c.idEmpleado),
      `${c.nombreCompleto} ya tiene acceso a ${this.carteraActual()}.`,
    );
  }

  private async accion(fn: () => Promise<unknown>, exito: string): Promise<void> {
    if (this.enviando()) return;
    this.enviando.set(true);
    try {
      await fn();
      this.avisos.open(exito, 'Cerrar', { duration: 6000 });
      this.limpiar();
    } catch (e) {
      this.avisos.open(this.mensajeDeError(e), 'Cerrar', { duration: 6000 });
    } finally {
      this.enviando.set(false);
    }
  }

  protected limpiar(): void {
    this.coincidencias.set([]);
    queueMicrotask(() => this.campanaPorDefecto());
    this.horasPrevias = { entrada: '', salida: '' };
    this.alternarHoras(false);
    this.formulario.reset({
      idPuesto: 0,
      idSexo: 0,
      horaEntrada: HORA_ENTRADA_DEFECTO,
      horaSalida: HORA_SALIDA_DEFECTO,
      noAplicaHorario: false,
      nombre: '',
      paterno: '',
      materno: '',
    });
  }

  private mensajeDeError(e: unknown): string {
    if (e instanceof HttpErrorResponse) {
      return e.error?.title ?? 'No se pudo dar de alta al empleado.';
    }
    return 'No hay comunicación con el servidor.';
  }
}
