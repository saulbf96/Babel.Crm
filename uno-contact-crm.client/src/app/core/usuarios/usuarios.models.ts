export interface UsuarioAdmin {
  idUsuario: number;
  usuario: string;
  empleado: string;
  puesto: string;
  cartera: string;
  activo: boolean;
  bloqueado: boolean;
  debeCambiarContrasena: boolean;
  ultimoAcceso: string | null;
}
