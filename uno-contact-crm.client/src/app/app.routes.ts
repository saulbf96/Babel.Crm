import { Routes } from '@angular/router';
import { perfilGuard, sesionGuard } from './core/sesion/perfil.guard';
import { Acceso } from './features/acceso/acceso';
import { AccesoDenegado } from './features/acceso-denegado/acceso-denegado';
import { Empleados } from './features/empleados/empleados';
import { Inicio } from './features/inicio/inicio';
import { Shell } from './layout/shell';
import { EnConstruccion } from './shared/en-construccion/en-construccion';

export const routes: Routes = [
  { path: 'acceso', component: Acceso, title: 'Iniciar sesión · UNO Contact CRM' },
  {
    path: '',
    component: Shell,
    canActivate: [sesionGuard],
    children: [
      { path: '', pathMatch: 'full', redirectTo: 'inicio' },
      { path: 'inicio', component: Inicio, title: 'Inicio · UNO Contact CRM' },
      {
        path: 'asesor',
        canMatch: [perfilGuard('Asesor')],
        component: EnConstruccion,
        data: { titulo: 'Gestión de cartera' },
        title: 'Gestión de cartera · UNO Contact CRM',
      },
      {
        path: 'supervision',
        canMatch: [perfilGuard('Supervisor')],
        component: EnConstruccion,
        data: { titulo: 'Supervisión' },
        title: 'Supervisión · UNO Contact CRM',
      },
      {
        path: 'administracion',
        pathMatch: 'full',
        redirectTo: 'administracion/empleados',
      },
      {
        path: 'administracion/empleados',
        canMatch: [perfilGuard('Administrador')],
        component: Empleados,
        title: 'Consulta de empleados · UNO Contact CRM',
      },
      { path: 'acceso-denegado', component: AccesoDenegado, title: 'Acceso denegado · UNO Contact CRM' },
    ],
  },
  { path: '**', redirectTo: '' },
];
