//
//  BagOfWords.swift
//  SkyLight
//
//  Created by Luke Van In on 2023/01/26.
//

import Foundation

import SIFTMetal


final class KMeansCluster {
    
    struct Cluster {
        var centroid: FloatVector
        var inverseCovarianceMatrix: FloatMatrix
        
        func mahanalobisDistance(from vector: FloatVector) -> Float {
            let x = vector - centroid
            let d2 = x.dotProduct(with: inverseCovarianceMatrix).dotProduct(with: x)
            let d = sqrt(d2)
            return d
        }
    }
    
    let k: Int
    let d: Int
    
    var clusters: [Cluster]
    
    init(k: Int, d: Int) {
        self.k = k
        self.d = d
        self.clusters = {
            var clusters: [Cluster] = []
            for _ in 0 ..< k {
                let cluster = Cluster(
                    centroid: FloatVector(dimension: d),
                    inverseCovarianceMatrix: FloatMatrix(columns: d, rows: d)
                )
                clusters.append(cluster)
            }
            return clusters
        }()
    }
    
    func train(vectors: [FloatVector], maximumIterations: Int = 20, maximumError: Float = 0.001) {
        print("kmeans \(k): training with \(vectors.count) vectors")
        var centroids: [FloatVector] = []
        var localClusters: [[FloatVector]] = []
        
        // Create random centroids.
        for _ in 0 ..< k {
            var components = Array<Float>(repeating: 0, count: d)
            for j in 0 ..< d {
                components[j] = .random(in: -1...1)
            }
            let centroid = FloatVector(components).normalized()
            centroids.append(centroid)
        }

        // Iterate until centroids converge.
        for t in 0 ..< maximumIterations {
            localClusters = Array(repeating: [], count: k)
            
            // Assign vectors to nearest cluster
            for vector in vectors {
                var minimumDistance: Float = .greatestFiniteMagnitude
                var nearestClusterIndex: Int!
                for i in 0 ..< k {
                    let centroid = centroids[i]
                    let distance = vector.distance(to: centroid)
                    if distance < minimumDistance {
                        minimumDistance = distance
                        nearestClusterIndex = i
                    }
                }
                localClusters[nearestClusterIndex].append(vector)
            }
            
            // Compute centroid of each cluster
            let oldCentroids = centroids
            var newCentroids = centroids
            for i in 0 ..< k {
                let points = localClusters[i]
                guard points.count > 0 else {
                    // No points assigned to this cluster.
                    continue
                }
                var centroid = points[0]
                for j in 1 ..< points.count {
                    centroid = centroid + points[j]
                }
                centroid = centroid / Float(points.count)
                newCentroids[i] = centroid
            }
            centroids = newCentroids
            
            // Compute summed error
            var error: Float = 0
            for i in 0 ..< k {
                let a = newCentroids[i]
                let b = oldCentroids[i]
                let e = a.distance(to: b)
                error += (e * e)
            }
            print("iteration \(t) sum of error: \(error)")
            
            if error <= maximumError {
                break
            }
        }
        
        print("k-means converged")
        for i in 0 ..< k {
            print("cluster \(i) = \(localClusters[i].count) \(centroids[i])")
        }

        // Solution has converged. Compute covariance matrix for each cluster
        var clusters = [Cluster]()
//        let identity = FloatMatrix.identity(dimensions: d)
        for i in 0 ..< k {
            let covarianceMatrix: FloatMatrix
            let localCluster = localClusters[i]
            print("k-means \(i) out of \(k) compute covariance of \(localCluster.count) points")
            guard localCluster.count > 50 else {
                print("❗️ SKIPPED: Not enough points: \(localCluster.count)")
                continue
            }
//            let a = FloatMatrix(localCluster)
//            let b = a.covarianceMatrix()
//            do {
//                covarianceMatrix = try b.inverse()
//            }
//            catch {
//                continue
//            }
            let cluster = Cluster(
                centroid: centroids[i],
                inverseCovarianceMatrix: .identity(dimensions: d)
            )
            clusters.append(cluster)
        }
        self.clusters = clusters
        print("Found clusters \(clusters.count)  out of \(k)")
    }
    
    func bagOfWords(for vectors: [FloatVector]) -> FloatVector? {
//        precondition(!vectors.isEmpty)
//        let sampleSize = 10
//        guard vectors.count >= sampleSize else {
//            // Not enough descriptors
//            print("❗️ SKIPPED: Not enough vectors: \(vectors.count)")
//            return nil
//        }
        
        var output = FloatVector(dimension: k)
        
//        for vector in vectors {
//            let i = nearestCluster(to: vector)
//
//            output[i] += 1
//        }
        
//        let sample = vectors.lazy.shuffled().prefix(upTo: sampleSize)
        let sample = vectors

//        let threshold: Float = 0.01
        for vector in sample {
            guard let index = nearestCluster(to: vector) else {
                continue
            }
            output[index] += 1
//            var match = [Int]()
//            for i in 0 ..< clusters.count {
                
//                let cluster = clusters[i]
                //            let distance = cluster.mahanalobisDistance(from: vector)
//                let distance = vector.distance(to: cluster.centroid)
//                if distance < threshold {
//                    match.append(i)
//                    let t = 1.0 - (distance / threshold)
//                    output[i] += t
//                }
//            }
//            print("words", match, "for vector", vector)
        }
        
        print("bag of words", output)

        guard output.sum() > 0 else {
            print("❗️ SKIPPED: No words: \(output)")
            return nil
        }
        // print("bag of words", output, "for", vectors.count, "vectors")
//        precondition(output.sum() > 0)
        return output.normalized()
//        return output.standardized()
//        return output
    }
    
//    func nearestClusters(to vector: FloatVector) -> [Int] {
//        var output = [Int]()
//        for i in 0 ..< k {
//            let cluster = clusters[i]
////            let distance = cluster.mahanalobisDistance(from: vector)
//            let distance = vector.distance(to: cluster.centroid)
//            if distance < 0.1 {
//                output.append(i)
//            }
//        }
//        print("nearest clusters: \(output)")
//        return output
//    }

    func nearestCluster(to vector: FloatVector) -> Int? {
        var bestDistance: Float = .greatestFiniteMagnitude
        var secondBestDistance: Float?
        var nearestClusterIndex: Int!
        for i in 0 ..< clusters.count {
            let cluster = clusters[i]
//            let centroid = clusters[i].centroid
//            let distance = vector.distance(to: centroid)
            let distance = cluster.mahanalobisDistance(from: vector)
            if distance < bestDistance {
                secondBestDistance = bestDistance
                bestDistance = distance
                nearestClusterIndex = i
            }
        }
//        guard bestDistance < 1 else {
//            return nil
//        }
//        guard let secondBestDistance else {
//            return nil
//        }
//        let r = bestDistance / secondBestDistance
//        guard r > 0.8 else {
//            return nil
//        }
//        print("nearest cluster distance: \(bestDistance)")
        return nearestClusterIndex
    }
}
