import { Entity, ANNOTATION_LOCATION,  ANNOTATION_ORIGIN_LOCATION } from '@backstage/catalog-model';
import {
  EntityProvider,
  EntityProviderConnection,
} from '@backstage/plugin-catalog-node';

/**
 * Provides entities from crossplane.
 */
export class CrossplaneProvider implements EntityProvider {
  private connection?: EntityProviderConnection;

  

  getProviderName(): string {
    return `crossplane`;
  }

  async connect(connection: EntityProviderConnection): Promise<void> {
    this.connection = connection;
  }

  async run(): Promise<void> {
    if (!this.connection) {
      throw new Error('Not initialized');
    }

    const entities: Entity[] = [
        {
            apiVersion: "backstage.io/v1alpha1",
            kind: "Resource",
            metadata: {
                name: "provider-provided",
                annotations: {
                    [ANNOTATION_LOCATION]: "crossplane:provided",
                    [ANNOTATION_ORIGIN_LOCATION]: "crossplane:provided"
                }
            },
            spec: {
                type: "kubernetes-cluster",
                system: "back-stack",
                owner: "infrastructure"
            }
        } as Entity
    ]

    await this.connection.applyMutation({
      type: 'full',
      entities: entities.map(entity => ({
        entity,
        locationKey: `crossplane`,
      })),
    });
  }
}