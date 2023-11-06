import { CatalogBuilder } from '@backstage/plugin-catalog-backend';
import { ScaffolderEntitiesProcessor } from '@backstage/plugin-scaffolder-backend';
import { Router } from 'express';
import { PluginEnvironment } from '../types';
import { CrossplaneProvider } from './crossplane';

export default async function createPlugin(
  env: PluginEnvironment,
): Promise<Router> {
  const builder = await CatalogBuilder.create(env);
  const crossplane = new CrossplaneProvider(env);
  builder.addEntityProvider(crossplane);
  builder.addProcessor(new ScaffolderEntitiesProcessor());
  const { processingEngine, router } = await builder.build();
  await processingEngine.start();
  await env.scheduler.scheduleTask({
    id: 'run_crossplane_refresh',
    fn: async () => {
      await crossplane.run();
    },
    frequency: {minutes: 1},
    timeout: {seconds: 30}
  })
  return router;
}
