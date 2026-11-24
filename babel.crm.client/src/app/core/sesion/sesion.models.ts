export type Perfil = 'Asesor' | 'Supervisor' | 'Administrador';

export interface OpcionMenu {
  clave: string;
  titulo: string;
  icono: string;
  ruta: string;
}

export interface Sesion {
  idEmpleado: number;
  usuario: string;
  perfiles: Perfil[];
  menu: OpcionMenu[];
}

export interface ResultadoInicioSesion {
  debeCambiarContrasena: boolean;
}
