export type Perfil = 'Asesor' | 'Supervisor' | 'Administrador';

export interface OpcionMenu {
  clave: string;
  titulo: string;
  icono: string;
  ruta: string;
  grupo?: string;
}

export interface Sesion {
  idEmpleado: number;
  usuario: string;
  idCartera: number;
  cartera: string;
  debeCambiarContrasena: boolean;
  perfiles: Perfil[];
  menu: OpcionMenu[];
  /** Por qué debe cambiar la contraseña: lo forzó un admin o ya venció (90 días). */
  motivoCambioContrasena?: MotivoCambioContrasena | null;
}

export type MotivoCambioContrasena = 'Forzado' | 'Vencida';

export interface ResultadoInicioSesion {
  debeCambiarContrasena: boolean;
  motivoCambioContrasena?: MotivoCambioContrasena | null;
}
