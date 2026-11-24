import { Routes } from '@angular/router';
import { perfilGuard, sesionGuard } from './core/sesion/perfil.guard';
import { Acceso } from './features/acceso/acceso';
import { AccesoDenegado } from './features/acceso-denegado/acceso-denegado';
import { Empleados } from './features/empleados/empleados';
import { Inicio } from './features/inicio/inicio';
import { Shell } from './layout/shell';
import { EnConstruccion } from './shared/en-construccion/en-construccion';

export const routes: Routes = [
  { path: 'acceso', component: Acceso, title: 'Iniciar sesión · BABEL CRM' },
  {
    path: '',
    component: Shell,
    canActivate: [sesionGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'inicio' },
      { path: 'inicio', component: Inicio, title: 'Inicio · BABEL CRM' },
      {
        path: 'asesor',
        canMatch: [perfilGuard('Asesor')],
        component: EnConstruccion,
        data: { titulo: 'Gestión de cartera' },
        title: 'Gestión de cartera · BABEL CRM',
      },
      {
        path: 'supervision',
        canMatch: [perfilGuard('Supervisor')],
        component: EnConstruccion,
        data: { titulo: 'Supervisión' },
        title: 'Supervisión · BABEL CRM',
      },
      {
        path: 'administracion',
        canMatch: [perfilGuard('Administrador')],
        component: EnConstruccion,
        data: { titulo: 'Administración' },
        title: 'Administración · BABEL CRM',
      },
      {
        path: 'administracion/empleados',
        canMatch: [perfilGuard('Administrador')],
        component: Empleados,
        title: 'Consulta de empleados · BABEL CRM',
      },
      { path: 'acceso-denegado', component: AccesoDenegado, title: 'Acceso denegado · BABEL CRM' },
    ],
  },
  { path: '**', redirectTo: '' },
];
