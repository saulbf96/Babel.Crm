/** Renglón de "Consulta de empleados" (paridad con FRM_CONSULTAEMPLEADOS). */
export interface EmpleadoResumen {
  idEmpleado: number;
  nombre: string;
  paterno: string;
  materno: string | null;
  nombreCompleto: string;
  usuario: string | null;
  idPuesto: number;
  puesto: string;
  idDepartamento: number;
  departamento: string;
  idCartera: number | null;
  cartera: string | null;
  idSexo: number;
  sexo: string;
  idTurno: number | null; // empleados migrados de BABEL
  turno: string | null;
  horaEntrada: string | null; // "HH:mm:ss" (altas nuevas)
  horaSalida: string | null;
  aplicaHorario: boolean; // false = entra a cualquier hora
  fechaNacimiento: string | null; // ISO yyyy-MM-dd
  fechaIngreso: string; // ISO yyyy-MM-dd
  rfc: string | null;
  curp: string | null;
  nss: number | null;
  email: string | null;
  activo: boolean;
  fechaRegistro: string;
}

export interface FiltroEmpleados {
  nombre?: string;
  idPuesto?: number;
  idCartera?: number;
  soloActivos?: boolean;
}

/** Datos del alta de empleado (equivale a FRM_ALTAEMPLEADOS: usa la cartera de la sesión). */
export interface SolicitudAltaEmpleado {
  idPuesto: number;
  idSexo: number;
  horaEntrada: string | null; // "HH:mm:ss"; las dos vacías = no aplica horario
  horaSalida: string | null;
  aplicaHorario: boolean;
  nombre: string;
  paterno: string;
  materno: string;
  /** true = el admin confirmó que es OTRA persona con el mismo nombre. */
  confirmarHomonimo?: boolean;
  /** Permisos que tendrá (claves de menú). Sin enviar = solo lo de su puesto. */
  permisos?: string[];
  /** Campañas a las que pertenece (1 o más). */
  carteras?: number[];
  /** Con la que entra al iniciar sesión. */
  carteraPrincipal?: number | null;
}

/** Renglón del historial de altas (fuente: bitácora del sistema). */
export interface AltaRegistrada {
  fechaAlta: string; // fecha y hora
  registradoPor: string;
  nombreCompleto: string;
  usuario: string | null;
  puesto: string;
  horaEntrada: string | null;
  horaSalida: string | null;
  aplicaHorario: boolean;
  activo: boolean;
}

/** Edición de empleado (NUEVO: BABEL no tenía edición). */
export interface SolicitudEdicionEmpleado {
  nombre: string;
  paterno: string;
  materno: string;
  idPuesto: number;
  idSexo: number;
  horaEntrada: string | null;
  horaSalida: string | null;
  aplicaHorario: boolean;
  /** Permisos que quedarán. Sin enviar = no se cambian. */
  permisos?: string[];
}

/** Si trae coincidencias, NO se dio de alta: la persona ya existe. */
export interface ResultadoAltaEmpleado {
  idEmpleado: number;
  mensaje: string;
  /** Usuario del sistema que se le creó (cambiará su contraseña al primer acceso). */
  usuario?: string | null;
  /** Contraseña temporal ÚNICA: se muestra una sola vez. */
  contrasenaTemporal?: string | null;
  coincidencias?: EmpleadoCoincidente[] | null;
}

export interface EmpleadoCoincidente {
  idEmpleado: number;
  nombreCompleto: string;
  puesto: string;
  activo: boolean;
  fechaIngreso: string;
  carteraActiva: string | null;
  enEstaCartera: boolean;
  tieneAcceso: boolean;
  usuario: string | null;
}
