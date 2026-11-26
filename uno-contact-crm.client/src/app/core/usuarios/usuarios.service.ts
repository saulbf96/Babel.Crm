import { HttpClient, HttpParams } from '@angular/common/http';
import { Injectable, inject } from '@angular/core';
import { firstValueFrom } from 'rxjs';
import { UsuarioAdmin } from './usuarios.models';

/** Administración de usuarios (perfil Administrador, alcance por campaña en el servidor). */
@Injectable({ providedIn: 'root' })
export class UsuariosService {
  private readonly http = inject(HttpClient);

  consultar(soloBloqueados: boolean): Promise<UsuarioAdmin[]> {
    const params = new HttpParams().set('soloBloqueados', soloBloqueados);
    return firstValueFrom(this.http.get<UsuarioAdmin[]>('/api/usuarios', { params }));
  }

  desbloquear(idUsuario: number): Promise<void> {
    return firstValueFrom(this.http.post<void>(`/api/usuarios/${idUsuario}/desbloquear`, {}));
  }

  forzarCambio(idUsuario: number): Promise<void> {
    return firstValueFrom(this.http.post<void>(`/api/usuarios/${idUsuario}/forzar-cambio`, {}));
  }

  bloquear(idUsuario: number): Promise<void> {
    return firstValueFrom(this.http.post<void>(`/api/usuarios/${idUsuario}/bloquear`, {}));
  }
}
