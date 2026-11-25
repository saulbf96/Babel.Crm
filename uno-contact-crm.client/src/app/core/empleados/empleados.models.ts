/** Renglón de "Consulta de empleados" (paridad con FRM_CONSULTAEMPLEADOS). */
export interface EmpleadoResumen {
  idEmpleado: number;
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
  idTurno: number;
  turno: string;
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
  idTurno: number;
  nombre: string;
  paterno: string;
  materno: string;
}

export interface ResultadoAltaEmpleado {
  idEmpleado: number;
  mensaje: string;
}
