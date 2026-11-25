/** Cargas de asignaciones (staging). */
export interface ProcesoAsignacion {
  idProceso: number;
  nombre: string;
  descripcion: string | null;
}

export interface CargaAsignacion {
  idCarga: number;
  idCartera: number;
  cartera: string;
  proceso: number;
  procesoNombre: string;
  nombreArchivo: string;
  estatus: string;
  totalRegistros: number;
  procesados: number;
  errores: number;
  mensaje: string | null;
  usuario: string | null;
  fechaInicio: string;
  fechaFin: string | null;
}

export interface SolicitudCarga {
  idCartera: number;
  proceso: number;
  nombreArchivo: string;
  rutaArchivo?: string | null;
  filas?: string[] | null;
}

export interface ResultadoCarga {
  idCarga: number;
  filas: number;
  mensaje: string;
}
