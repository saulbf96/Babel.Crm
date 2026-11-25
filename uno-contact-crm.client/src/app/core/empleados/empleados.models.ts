export interface EmpleadoResumen {
  idEmpleado: number;
  idCliente: number;
  cliente: string;
  nombreCompleto: string;
  idPuesto: number;
  puesto: string;
  idDepartamento: number;
  departamento: string;
  rfc: string | null;
  email: string | null;
  fechaIngreso: string; // ISO yyyy-MM-dd
  activo: boolean;
}

export interface FiltroEmpleados {
  nombre?: string;
  idPuesto?: number;
  idCliente?: number;
  soloActivos?: boolean;
}
