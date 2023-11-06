import { Entity, ANNOTATION_LOCATION,  ANNOTATION_ORIGIN_LOCATION } from '@backstage/catalog-model';
import {
  EntityProvider,
  EntityProviderConnection,
} from '@backstage/plugin-catalog-node';
import { KubeConfig, User, Cluster } from '@kubernetes/client-node'
import { PluginEnvironment } from '../types';
import fs from 'fs-extra';
import fetch, { RequestInit } from 'node-fetch';
import * as https from 'https';

/**
 * Provides entities from crossplane.
 */
export class CrossplaneProvider implements EntityProvider {
  private env: PluginEnvironment;
  private connection?: EntityProviderConnection;
  private kc?: KubeConfig;

  constructor(env: PluginEnvironment) {
    this.env = env;
  }

  getProviderName(): string {
    return `crossplane`;
  }

  async connect(connection: EntityProviderConnection): Promise<void> {
    this.connection = connection;
    this.kc = new KubeConfig();
    this.kc.loadFromCluster();
  }

  async getClusters(clusterType: string): Promise<any[]> {
    if (!this.kc) {
      throw new Error('Not initialized');
    }
    const user = this.kc.getCurrentUser() as User;
    const token = fs.readFileSync(user.authProvider.config.tokenFile).toString();

    const requestInit: RequestInit = {
      method: 'GET',
      headers: {
        Accept: 'application/json',
        'Content-Type': 'application/json',
        Authorization: `Bearer ${token}`,
      },
    };

    const cluster = this.kc.getCurrentCluster() as Cluster;
    const url = new URL(cluster.server);

    if (url.protocol === 'https:') {
      requestInit.agent = new https.Agent({
        ca: fs.readFileSync(cluster.caFile as string),
      });
    }

    if (url.pathname === '/') {
      url.pathname = `/apis/backstack.cncf.io/v1alpha1/namespaces/default/${clusterType}`;
    } else {
      url.pathname += `/apis/backstack.cncf.io/v1alpha1/namespaces/default/${clusterType}`;
    }

    const clusters: {kind: any, items: any} =  await fetch(url, requestInit).then(res => res.json());
    return clusters.items;
  }

  async run(): Promise<void> {
    if (!this.connection) {
      throw new Error('Not initialized');
    }

    this.env.logger.info("Running crossplane entity import");

    const aksclusters = await this.getClusters("aksclusters");
    const eksclusters = await this.getClusters("eksclusters");
    
    const entities: Entity[] = aksclusters.concat(eksclusters).map((item: any): Entity => ({
        apiVersion: "backstage.io/v1alpha1",
        kind: "Resource",
        metadata: {
            name: item.metadata.name,
            annotations: {
                [ANNOTATION_LOCATION]: `crossplane:${item.metadata.namespace}/${item.metadata.name}`,
                [ANNOTATION_ORIGIN_LOCATION]: `crossplane:${item.metadata.namespace}/${item.metadata.name}`,
                "vault.io/secrets-path": `${item.metadata.namespace}/${item.metadata.name}`,
            }
        },
        spec: {
            type: "kubernetes-cluster",
            system: "back-stack",
            owner: "infrastructure"
        }
    }));

    await this.connection.applyMutation({
      type: 'full',
      entities: entities.map(entity => ({
        entity,
        locationKey: `crossplane`,
      })),
    });
  }
}